import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../app/flavor.dart';
import '../models/device.dart';

/// Result from CPU/GPU online search.
class ChipSearchResult {
  final String source; // 'preset', 'TechPowerUp', 'AMD', or 'Intel'
  final String? sourceUrl;

  // CPU fields
  final String? model;
  final String? architecture;
  final String? frequency;
  final int? performanceCores;
  final int? efficiencyCores;
  final int? threads;
  final String? cache;

  const ChipSearchResult({
    required this.source,
    this.sourceUrl,
    this.model,
    this.architecture,
    this.frequency,
    this.performanceCores,
    this.efficiencyCores,
    this.threads,
    this.cache,
  });

  CpuInfo toCpuInfo() => CpuInfo(
        model: model,
        architecture: architecture,
        frequency: frequency,
        performanceCores: performanceCores,
        efficiencyCores: efficiencyCores,
        threads: threads,
        cache: cache,
      );

  GpuInfo toGpuInfo() => GpuInfo(
        model: model,
        architecture: architecture,
      );
}

/// Service to search for CPU/GPU specs from online databases.
///
/// Sources:
/// - TechPowerUp: CPU th/td tables, GPU og:description meta tags
/// - AMD (official): CPU/GPU product pages with dt/dd spec pairs
/// - Intel (official): URL slug contains model, cache, max frequency
///   (pages return 403 but URL is provided for user reference)
///
/// Uses Startpage to discover URLs for all sources.
class ChipSearchService {
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// Search for a CPU by model name.
  /// Searches local [presets] first, then tries online sources in parallel.
  static Future<List<ChipSearchResult>> searchCpu(
    String query,
    List<CpuInfo> presets,
  ) async {
    final results = <ChipSearchResult>[];
    final queryLower = query.toLowerCase();

    // 1. Local preset matches
    for (final cpu in presets) {
      if (cpu.model == null) continue;
      if (cpu.model!.toLowerCase().contains(queryLower)) {
        results.add(ChipSearchResult(
          source: 'preset',
          model: cpu.model,
          architecture: cpu.architecture,
          frequency: cpu.frequency,
          performanceCores: cpu.performanceCores,
          efficiencyCores: cpu.efficiencyCores,
          threads: cpu.threads,
          cache: cpu.cache,
        ));
      }
    }

    // 2. Online sources in parallel (full flavor only)
    if (AppFlavor.isFull) {
      final futures = await Future.wait([
        _searchTechPowerUpCpu(query).catchError((_) => null),
        _searchAmdCpu(query).catchError((_) => null),
        _searchIntelCpu(query).catchError((_) => null),
      ]);

      final existing = results.map((r) => r.model?.toLowerCase()).toSet();
      for (final online in futures) {
        if (online != null &&
            !existing.contains(online.model?.toLowerCase())) {
          results.add(online);
          existing.add(online.model?.toLowerCase());
        }
      }
    }

    return results;
  }

  /// Search for a GPU by model name.
  /// Searches local [presets] first, then tries online sources in parallel.
  static Future<List<ChipSearchResult>> searchGpu(
    String query,
    List<GpuInfo> presets,
  ) async {
    final results = <ChipSearchResult>[];
    final queryLower = query.toLowerCase();

    for (final gpu in presets) {
      if (gpu.model == null) continue;
      if (gpu.model!.toLowerCase().contains(queryLower)) {
        results.add(ChipSearchResult(
          source: 'preset',
          model: gpu.model,
          architecture: gpu.architecture,
        ));
      }
    }

    // Online sources in parallel (full flavor only)
    if (AppFlavor.isFull) {
      final futures = await Future.wait([
        _searchTechPowerUpGpu(query).catchError((_) => null),
        _searchAmdGpu(query).catchError((_) => null),
      ]);

      final existing = results.map((r) => r.model?.toLowerCase()).toSet();
      for (final online in futures) {
        if (online != null &&
            !existing.contains(online.model?.toLowerCase())) {
          results.add(online);
          existing.add(online.model?.toLowerCase());
        }
      }
    }

    return results;
  }

  // ──── Startpage URL discovery ────

  /// Find TechPowerUp URL via Startpage search.
  static Future<String?> _findTechPowerUpUrl(
      String query, String section) async {
    final resp = await http.post(
      Uri.parse('https://www.startpage.com/sp/search'),
      headers: {
        'User-Agent': _userAgent,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body:
          'query=${Uri.encodeComponent("$query site:techpowerup.com/$section")}',
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) return null;

    final urlMatch = RegExp(
      'https?://www\\.techpowerup\\.com/$section/[^\\s"&<]+\\.c\\d+',
    ).firstMatch(resp.body);
    return urlMatch?.group(0);
  }

  // ──── TechPowerUp CPU ────

  static Future<ChipSearchResult?> _searchTechPowerUpCpu(
      String query) async {
    final tpuUrl = await _findTechPowerUpUrl(query, 'cpu-specs');
    if (tpuUrl == null) return null;

    final resp = await http.get(
      Uri.parse(tpuUrl),
      headers: {'User-Agent': _userAgent, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) return null;

    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);

    // Parse th/td spec pairs
    final specs = <String, String>{};
    for (final m in RegExp(
      r'<th[^>]*>([^<]+)</th>\s*<td[^>]*>(.*?)</td>',
      dotAll: true,
    ).allMatches(html)) {
      final key = m.group(1)!.replaceAll(':', '').trim();
      final value = m
          .group(2)!
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        specs[key] = value;
      }
    }

    if (specs.isEmpty) return null;

    // Model name from <title>
    final titleMatch = RegExp(r'<title>([^<|]+)').firstMatch(html);
    String? model = titleMatch?.group(1)?.trim();
    if (model != null) {
      model = model.replaceAll(RegExp(r'\s*Specs$'), '');
    }

    // Architecture: codename / generation
    String? architecture = specs['Codename'];
    final generation = specs['Generation'];
    if (generation != null && generation.isNotEmpty) {
      architecture = generation;
    }

    // Frequency
    String? frequency;
    final base = specs['Frequency'];
    final turbo = specs['Turbo Clock'];
    if (base != null) {
      frequency = turbo != null && turbo != 'N/A'
          ? '$base (boost $turbo)'
          : base;
    }

    // Cores
    int? pCores, eCores, threads;
    final coresStr = specs['# of Cores'];
    final threadsStr = specs['# of Threads'];
    if (coresStr != null) {
      pCores = int.tryParse(coresStr);
    }
    if (threadsStr != null) {
      threads = int.tryParse(threadsStr);
    }
    // Hybrid architecture P/E cores
    final pCoreStr = specs['Performance Cores'];
    final eCoreStr = specs['Efficiency Cores'];
    if (pCoreStr != null) {
      pCores = int.tryParse(
          RegExp(r'(\d+)').firstMatch(pCoreStr)?.group(1) ?? '');
    }
    if (eCoreStr != null) {
      eCores = int.tryParse(
          RegExp(r'(\d+)').firstMatch(eCoreStr)?.group(1) ?? '');
    }

    // Cache
    String? cache;
    final l2 = specs['Cache L2'];
    final l3 = specs['Cache L3'];
    if (l2 != null || l3 != null) {
      final parts = <String>[];
      if (l2 != null) parts.add('L2 $l2');
      if (l3 != null) parts.add('L3 $l3');
      cache = parts.join(' / ');
    }

    return ChipSearchResult(
      source: 'TechPowerUp',
      sourceUrl: tpuUrl,
      model: model,
      architecture: architecture,
      frequency: frequency,
      performanceCores: pCores,
      efficiencyCores: eCores,
      threads: threads,
      cache: cache,
    );
  }

  // ──── TechPowerUp GPU (via og:meta) ────

  static Future<ChipSearchResult?> _searchTechPowerUpGpu(
      String query) async {
    final tpuUrl = await _findTechPowerUpUrl(query, 'gpu-specs');
    if (tpuUrl == null) return null;

    final resp = await http.get(
      Uri.parse(tpuUrl),
      headers: {'User-Agent': _userAgent, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) return null;

    final html = resp.body;

    // og:title → model name (e.g. "NVIDIA GeForce RTX 4090 Specs")
    final ogTitle = RegExp(
      r'<meta[^>]*property="og:title"[^>]*content="([^"]+)"',
    ).firstMatch(html);

    // og:description → specs
    // Format: "VENDOR CHIP, CLOCK MHz, CORES Cores, TMUs TMUs, ROPs ROPs,
    //          MEMORY MB MEMTYPE, MEMCLOCK MHz, BUS bit"
    final ogDesc = RegExp(
      r'<meta[^>]*property="og:description"[^>]*content="([^"]+)"',
    ).firstMatch(html);

    if (ogTitle == null || ogDesc == null) return null;

    String model = ogTitle.group(1)!.replaceAll(RegExp(r'\s*Specs$'), '');
    final desc = ogDesc.group(1)!;

    // Extract chip/architecture from first comma-separated part
    final parts = desc.split(', ');
    String? architecture;
    if (parts.isNotEmpty) {
      String chip = parts[0];
      // Strip vendor prefix
      for (final vendor in ['NVIDIA ', 'AMD ', 'Intel ', 'Apple ', 'Qualcomm ']) {
        if (chip.startsWith(vendor)) {
          chip = chip.substring(vendor.length);
          break;
        }
      }
      architecture = chip;
    }

    return ChipSearchResult(
      source: 'TechPowerUp',
      sourceUrl: tpuUrl,
      model: model,
      architecture: architecture,
    );
  }

  // ──── AMD (official) ────

  /// Find AMD product URL via Startpage.
  static Future<String?> _findAmdUrl(
      String query, String category) async {
    final resp = await http.post(
      Uri.parse('https://www.startpage.com/sp/search'),
      headers: {
        'User-Agent': _userAgent,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body:
          'query=${Uri.encodeComponent("$query specifications site:amd.com/en/products/$category")}',
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) return null;

    final match = RegExp(
      r'https?://www\.amd\.com/en/products/[^\s"<>&\\]+\.html',
    ).allMatches(resp.body).map((m) => m.group(0)!).where(
          (u) => !u.endsWith(r'\'),
        );
    return match.isNotEmpty ? match.first : null;
  }

  /// Parse AMD DT/DD spec pairs, cleaning tooltip noise.
  static Map<String, String> _parseAmdSpecs(String html) {
    final specs = <String, String>{};
    for (final m in RegExp(
      r'<dt[^>]*>(.*?)</dt>\s*<dd[^>]*>(.*?)</dd>',
      dotAll: true,
    ).allMatches(html)) {
      var key = m
          .group(1)!
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final val = m
          .group(2)!
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (key.isEmpty || val.isEmpty) continue;
      // AMD DT elements include tooltip text after the label.
      // Truncate at known tooltip starts.
      for (final marker in [
        ' Max boost ',
        ' Represents ',
        ' Boost Clock Frequency ',
        " 'Game Frequency'",
        ' AMD`s product warranty',
        ' EPYC-',
        ' All-core boost',
      ]) {
        final idx = key.indexOf(marker);
        if (idx > 0) {
          key = key.substring(0, idx);
          break;
        }
      }
      specs[key] = val;
    }
    return specs;
  }

  static Future<ChipSearchResult?> _searchAmdCpu(String query) async {
    final queryLower = query.toLowerCase();
    if (!queryLower.contains('amd') &&
        !queryLower.contains('ryzen') &&
        !queryLower.contains('epyc') &&
        !queryLower.contains('athlon') &&
        !queryLower.contains('threadripper')) {
      return null;
    }

    final url = await _findAmdUrl(query, 'processors');
    if (url == null) return null;

    final resp = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': _userAgent, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) return null;

    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    final specs = _parseAmdSpecs(html);
    if (specs.isEmpty) return null;

    final model = specs['Name'];
    final architecture = specs['Processor Architecture'] ??
        specs['Former Codename'];

    // Frequency
    String? frequency;
    final base = specs['Base Clock'];
    final boost = specs['Max. Boost Clock'];
    if (base != null) {
      frequency =
          boost != null ? '$base (boost $boost)' : base;
    } else if (boost != null) {
      frequency = boost;
    }

    // Cores & threads
    final cores = int.tryParse(specs['# of CPU Cores'] ?? '');
    final threads = int.tryParse(specs['# of Threads'] ?? '');

    // Cache
    String? cache;
    final l2 = specs['L2 Cache'];
    final l3 = specs['L3 Cache'];
    if (l2 != null || l3 != null) {
      final parts = <String>[];
      if (l2 != null) parts.add('L2 $l2');
      if (l3 != null) parts.add('L3 $l3');
      cache = parts.join(' / ');
    }

    return ChipSearchResult(
      source: 'AMD',
      sourceUrl: url,
      model: model,
      architecture: architecture,
      frequency: frequency,
      performanceCores: cores,
      threads: threads,
      cache: cache,
    );
  }

  static Future<ChipSearchResult?> _searchAmdGpu(String query) async {
    final queryLower = query.toLowerCase();
    if (!queryLower.contains('amd') &&
        !queryLower.contains('radeon') &&
        !queryLower.contains('rx ')) {
      return null;
    }

    final url = await _findAmdUrl(query, 'graphics');
    if (url == null) return null;

    final resp = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': _userAgent, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) return null;

    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    final specs = _parseAmdSpecs(html);
    if (specs.isEmpty) return null;

    final model = specs['Name'];
    // AMD GPU pages don't have a GPU Architecture field.
    // Use Series as fallback (e.g. "Radeon RX 7000 Series").
    final architecture = specs['GPU Architecture'] ?? specs['Series'];

    return ChipSearchResult(
      source: 'AMD',
      sourceUrl: url,
      model: model,
      architecture: architecture,
    );
  }

  // ──── Intel (official, limited — page returns 403 but URL slug has data) ────

  static Future<ChipSearchResult?> _searchIntelCpu(String query) async {
    final queryLower = query.toLowerCase();
    if (!queryLower.contains('intel') &&
        !queryLower.contains('core') &&
        !queryLower.contains('xeon') &&
        !queryLower.contains('celeron') &&
        !queryLower.contains('pentium')) {
      return null;
    }

    // Find Intel product spec URL via Startpage
    final resp = await http.post(
      Uri.parse('https://www.startpage.com/sp/search'),
      headers: {
        'User-Agent': _userAgent,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body:
          'query=${Uri.encodeComponent("$query specifications site:intel.com/content/www/us/en/products/sku")}',
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) return null;

    final urlMatch = RegExp(
      r'https?://www\.intel\.com/content/www/us/en/products/sku/\d+/([^\s"<>&\\]+?)/specifications\.html',
    ).firstMatch(resp.body);
    if (urlMatch == null) return null;

    final specUrl = urlMatch.group(0)!;
    final slug = urlMatch.group(1)!;

    // Parse model name from slug: intel-core-i9-processor-14900k-36m-cache-...
    var nameSlug = slug.replaceAll(RegExp(r'-\d+m-cache.*'), '');
    // Convert slug to readable name
    var model = nameSlug
        .split('-')
        .map((w) => w == 'intel'
            ? 'Intel'
            : w == 'processor'
                ? ''
                : w)
        .where((w) => w.isNotEmpty)
        .join(' ');
    // Capitalize known tokens
    model = model
        .replaceAllMapped(RegExp(r'\b(core|ultra|xeon|celeron|pentium)\b',
            caseSensitive: false), (m) {
      final w = m.group(1)!;
      return w[0].toUpperCase() + w.substring(1);
    });
    // Fix model numbers like "i52520m" → "i5-2520M" (best effort)
    model = model.replaceAllMapped(
      RegExp(r'\b(i\d)(\d{3,})([a-z]*)\b', caseSensitive: false),
      (m) => '${m.group(1)}-${m.group(2)}${m.group(3)!.toUpperCase()}',
    );

    // Extract cache from slug
    String? cache;
    final cacheMatch = RegExp(r'(\d+)m-cache').firstMatch(slug);
    if (cacheMatch != null) cache = '${cacheMatch.group(1)} MB';

    // Extract max frequency from slug
    String? frequency;
    final freqMatch =
        RegExp(r'up-to-(\d+)-(\d+)-ghz').firstMatch(slug);
    if (freqMatch != null) {
      frequency =
          'Up to ${freqMatch.group(1)}.${freqMatch.group(2)} GHz';
    }

    return ChipSearchResult(
      source: 'Intel',
      sourceUrl: specUrl,
      model: model,
      frequency: frequency,
      cache: cache,
    );
  }
}
