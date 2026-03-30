import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../app/flavor.dart';

/// A single search result from an online device database.
class DeviceSearchResult {
  final String source;
  final String? sourceUrl;
  final String? name;
  final String? brand;
  final String? model;
  final String? thumbnailUrl;
  final String? imageUrl;
  final String? chipset;
  final String? gpuName;
  final String? ram;
  final String? storage;
  final String? screenSize;
  final int? screenResolutionW;
  final int? screenResolutionH;
  final String? battery;
  final String? os;
  final DateTime? releaseDate;
  final bool detailFetched;

  const DeviceSearchResult({
    required this.source,
    this.sourceUrl,
    this.name,
    this.brand,
    this.model,
    this.thumbnailUrl,
    this.imageUrl,
    this.chipset,
    this.gpuName,
    this.ram,
    this.storage,
    this.screenSize,
    this.screenResolutionW,
    this.screenResolutionH,
    this.battery,
    this.os,
    this.releaseDate,
    this.detailFetched = false,
  });

  DeviceSearchResult withDetail({
    String? imageUrl,
    String? chipset,
    String? gpuName,
    String? ram,
    String? storage,
    String? screenSize,
    int? screenResolutionW,
    int? screenResolutionH,
    String? battery,
    String? os,
    DateTime? releaseDate,
  }) =>
      DeviceSearchResult(
        source: source,
        sourceUrl: sourceUrl,
        name: name,
        brand: brand,
        model: model,
        thumbnailUrl: thumbnailUrl,
        imageUrl: imageUrl ?? this.imageUrl,
        chipset: chipset ?? this.chipset,
        gpuName: gpuName ?? this.gpuName,
        ram: ram ?? this.ram,
        storage: storage ?? this.storage,
        screenSize: screenSize ?? this.screenSize,
        screenResolutionW: screenResolutionW ?? this.screenResolutionW,
        screenResolutionH: screenResolutionH ?? this.screenResolutionH,
        battery: battery ?? this.battery,
        os: os ?? this.os,
        releaseDate: releaseDate ?? this.releaseDate,
        detailFetched: true,
      );
}

/// Service to search for device specs from online databases.
class DeviceSearchService {
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// Search for devices by name. Returns quick results (name + thumbnail).
  static Future<List<DeviceSearchResult>> search(String query) async {
    if (AppFlavor.isStore) return [];
    final results = await Future.wait([
      _searchGSMArena(query).catchError((_) => <DeviceSearchResult>[]),
      _searchNotebookcheck(query).catchError((_) => <DeviceSearchResult>[]),
    ]);
    return results.expand((r) => r).toList();
  }

  /// Fetch full detail for a search result (scrapes the detail page).
  static Future<DeviceSearchResult> fetchDetail(
      DeviceSearchResult result) async {
    if (AppFlavor.isStore) return result;
    if (result.sourceUrl == null) return result;
    switch (result.source) {
      case 'GSMArena':
        return _fetchGSMArenaDetail(result);
      case 'Notebookcheck':
        return _fetchNotebookcheckDetail(result);
      default:
        return result;
    }
  }

  // ──── GSMArena ────

  static Future<List<DeviceSearchResult>> _searchGSMArena(
      String query) async {
    final url = Uri.parse(
      'https://www.gsmarena.com/results.php3'
      '?sQuickSearch=yes&sName=${Uri.encodeComponent(query)}',
    );
    final resp = await http.get(url, headers: {
      'User-Agent': _userAgent,
      'Accept': 'text/html,application/xhtml+xml',
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];

    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);

    // Find the <div class="makers"> section
    final makersMatch =
        RegExp(r'<div\s+class="makers">(.*?)</div>', dotAll: true)
            .firstMatch(html);
    if (makersMatch == null) return [];
    final makersHtml = makersMatch.group(1)!;

    final results = <DeviceSearchResult>[];
    final liPattern = RegExp(r'<li>(.*?)</li>', dotAll: true);

    for (final liMatch in liPattern.allMatches(makersHtml)) {
      if (results.length >= 10) break;
      final li = liMatch.group(1)!;

      final hrefMatch = RegExp(r'href="([^"]+)"').firstMatch(li);
      final imgMatch = RegExp(r'<img[^>]*src="([^"]*)"').firstMatch(li);
      // Device name is inside <span>...</span>, may contain <br> between
      // brand and model, e.g. <span>Apple<br>iPhone 15 Pro</span>
      final spanMatch =
          RegExp(r'<span>(.*?)</span>', dotAll: true).firstMatch(li);
      final name = spanMatch
          ?.group(1)
          ?.replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final href = hrefMatch?.group(1);
      final thumbnail = imgMatch?.group(1);

      if (href != null && name != null && name.isNotEmpty) {
        final (brand, model) = _splitBrandModel(name);
        results.add(DeviceSearchResult(
          source: 'GSMArena',
          sourceUrl: 'https://www.gsmarena.com/$href',
          name: name,
          brand: brand,
          model: model,
          thumbnailUrl: thumbnail,
        ));
      }
    }

    return results;
  }

  static Future<DeviceSearchResult> _fetchGSMArenaDetail(
      DeviceSearchResult result) async {
    final url = Uri.parse(result.sourceUrl!);
    final resp = await http.get(url, headers: {
      'User-Agent': _userAgent,
      'Accept': 'text/html,application/xhtml+xml',
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return result;

    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);

    // Main device image — prefer GSMArena-hosted images only
    String? deviceImageUrl;
    final imgMatches = RegExp(
      r'class="specs-photo-main"[^>]*>.*?<img[^>]*src="([^"]*)"',
      dotAll: true,
    ).allMatches(html);
    for (final m in imgMatches) {
      final imgUrl = m.group(1);
      if (imgUrl != null && _isDeviceImage(imgUrl)) {
        deviceImageUrl = imgUrl;
        break;
      }
    }

    final chipset = _spec(html, 'chipset');
    final gpu = _spec(html, 'gpu');
    final memRaw = _spec(html, 'internalmemory');
    final (ram, storage) = _parseMemory(memRaw);
    final screenSize = _parseScreenSize(_spec(html, 'displaysize'));
    final (resW, resH) = _parseResolution(_spec(html, 'displayresolution'));
    final battery = _parseBattery(_spec(html, 'batdescription1'));
    final os = _spec(html, 'os');
    final releaseDate =
        _parseReleaseDate(_spec(html, 'released-hl') ?? _spec(html, 'status'));

    return result.withDetail(
      imageUrl: deviceImageUrl,
      chipset: chipset,
      gpuName: gpu,
      ram: ram,
      storage: storage,
      screenSize: screenSize,
      screenResolutionW: resW,
      screenResolutionH: resH,
      battery: battery,
      os: os,
      releaseDate: releaseDate,
    );
  }

  /// Extract a data-spec value from GSMArena HTML.
  static String? _spec(String html, String key) {
    final match = RegExp(
      'data-spec="$key"[^>]*>\\s*(.+?)\\s*</(?:td|span|div|li)>',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return null;
    // Strip inner HTML tags
    final raw = match
        .group(1)!
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return raw.isEmpty ? null : raw;
  }

  // ──── Parsers ────

  static (String?, String?) _splitBrandModel(String name) {
    final idx = name.indexOf(' ');
    if (idx == -1) return (name, null);
    return (name.substring(0, idx), name.substring(idx + 1));
  }

  static (String? ram, String? storage) _parseMemory(String? raw) {
    if (raw == null) return (null, null);
    final segment = raw.split(',').first.trim();

    // "128GB 8GB RAM" or "128 GB 8 GB RAM"
    final full = RegExp(r'(\d+)\s*GB\s+(\d+)\s*GB\s*RAM', caseSensitive: false)
        .firstMatch(segment);
    if (full != null) {
      return ('${full.group(2)} GB', '${full.group(1)} GB');
    }

    // "1TB 16GB RAM"
    final tbFull =
        RegExp(r'(\d+)\s*TB\s+(\d+)\s*GB\s*RAM', caseSensitive: false)
            .firstMatch(segment);
    if (tbFull != null) {
      return ('${tbFull.group(2)} GB', '${tbFull.group(1)} TB');
    }

    // RAM only: "8GB RAM"
    final ramOnly =
        RegExp(r'(\d+)\s*(GB|MB)\s*RAM', caseSensitive: false).firstMatch(raw);
    if (ramOnly != null) {
      return ('${ramOnly.group(1)} ${ramOnly.group(2)!.toUpperCase()}', null);
    }

    return (null, null);
  }

  static String? _parseScreenSize(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'([\d.]+)\s*inches').firstMatch(raw);
    return match != null ? '${match.group(1)}"' : null;
  }

  static (int?, int?) _parseResolution(String? raw) {
    if (raw == null) return (null, null);
    final match = RegExp(r'(\d+)\s*x\s*(\d+)').firstMatch(raw);
    if (match == null) return (null, null);
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  static String? _parseBattery(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'(\d+)\s*mAh').firstMatch(raw);
    return match != null ? '${match.group(1)} mAh' : null;
  }

  static DateTime? _parseReleaseDate(String? raw) {
    if (raw == null) return null;
    // "Released 2024, September 20" or "2024, September"
    final fullMatch =
        RegExp(r'(\d{4}),?\s+(\w+)\s+(\d{1,2})').firstMatch(raw);
    if (fullMatch != null) {
      final year = int.parse(fullMatch.group(1)!);
      final month = _parseMonth(fullMatch.group(2)!);
      final day = int.parse(fullMatch.group(3)!);
      if (month != null) return DateTime(year, month, day);
    }
    final monthMatch = RegExp(r'(\d{4}),?\s+(\w+)').firstMatch(raw);
    if (monthMatch != null) {
      final year = int.parse(monthMatch.group(1)!);
      final month = _parseMonth(monthMatch.group(2)!);
      if (month != null) return DateTime(year, month);
    }
    return null;
  }

  static int? _parseMonth(String m) {
    const months = {
      'january': 1, 'february': 2, 'march': 3, 'april': 4,
      'may': 5, 'june': 6, 'july': 7, 'august': 8,
      'september': 9, 'october': 10, 'november': 11, 'december': 12,
    };
    return months[m.toLowerCase()];
  }

  /// Check if an image URL is a genuine device photo (not an ad/affiliate).
  static bool _isDeviceImage(String url) {
    final lower = url.toLowerCase();
    // Reject Amazon, affiliate, ad, and tracking images
    if (lower.contains('amazon') ||
        lower.contains('amzn') ||
        lower.contains('affiliate') ||
        lower.contains('banner') ||
        lower.contains('advert') ||
        lower.contains('tracking') ||
        lower.contains('click.') ||
        lower.contains('/ad/') ||
        lower.contains('doubleclick') ||
        lower.contains('googlesyndication')) {
      return false;
    }
    // Accept GSMArena CDN images
    if (lower.contains('gsmarena.com') || lower.contains('fdn.gsmarena.com')) {
      return true;
    }
    // Accept common image extensions from any host
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp')) {
      return true;
    }
    return false;
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&[a-zA-Z]+;'), '')
        .replaceAll(RegExp(r'&#\d+;'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ──── Notebookcheck ────
  // Covers laptops, tablets, phones, smartwatches via their Laptop Search tool.
  // Search results include inline specs (GPU, CPU, screen, resolution, weight).

  static Future<List<DeviceSearchResult>> _searchNotebookcheck(
      String query) async {
    final url = Uri.parse(
      'https://www.notebookcheck.net/Laptop_Search.8223.0.html'
      '?model=${Uri.encodeComponent(query)}',
    );
    final resp = await http.get(url, headers: {
      'User-Agent': _userAgent,
      'Accept': 'text/html',
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];

    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    final results = <DeviceSearchResult>[];

    // Table rows with class "odd" or "even" contain the results.
    // Structure per row:
    //   <td>date</td><td>rating</td>
    //   <td><a href="URL">Name</a> | ... <br/>
    //       GPU, CPU, screen" resolution, weight</td>
    final rowPattern = RegExp(
      r'<tr[^>]*class="[^"]*(?:odd|even)[^"]*"[^>]*>(.*?)</tr>',
      dotAll: true,
    );

    for (final rowMatch in rowPattern.allMatches(html)) {
      if (results.length >= 8) break;
      final row = rowMatch.group(1)!;

      // Skip empty separator rows
      if (row.contains('nb_model') && row.contains('colspan')) continue;

      // Extract link and name
      final linkMatch = RegExp(
        r'<a[^>]*href="(https?://www\.notebookcheck\.net/[^"]+)"[^>]*>([^<]+)</a>',
      ).firstMatch(row);
      if (linkMatch == null) continue;

      final href = linkMatch.group(1)!;
      final name = linkMatch.group(2)!.trim();
      if (name.isEmpty || name.length < 3) continue;

      // Skip review articles — device entries are short names,
      // review titles are long or contain keywords like "review".
      if (name.length > 80 ||
          RegExp(r'review|comparison|versus|benchmark|test[:\s]',
                  caseSensitive: false)
              .hasMatch(name)) {
        continue;
      }

      // Extract inline specs after <br/>
      String? gpuName, chipset, screenSize;
      int? resW, resH;
      final brIdx = row.indexOf('<br/>');
      if (brIdx > 0) {
        final specsText = _stripHtml(row.substring(brIdx + 5));
        // Format: "GPU, CPU, screen" resolution, weight"
        // e.g. "Qualcomm Adreno 750, Qualcomm Snapdragon 8 Gen 3, 6.80" 3120x1440, 0.232 kg"
        // e.g. "Intel Arc Graphics 140V, Intel Core Ultra 7 258V, 14.00" 2880x1800, 0.98 kg"
        final parts = specsText.split(',').map((s) => s.trim()).toList();
        if (parts.isNotEmpty) gpuName = parts[0];
        if (parts.length > 1) chipset = parts[1];
        // Screen + resolution is in the part containing " (inches) and x
        for (final p in parts) {
          final screenMatch =
              RegExp(r'([\d.]+)"\s*(\d+)\s*x\s*(\d+)').firstMatch(p);
          if (screenMatch != null) {
            screenSize = '${screenMatch.group(1)}"';
            resW = int.parse(screenMatch.group(2)!);
            resH = int.parse(screenMatch.group(3)!);
            break;
          }
        }
      }

      final (brand, model) = _splitBrandModel(name);
      results.add(DeviceSearchResult(
        source: 'Notebookcheck',
        sourceUrl: href,
        name: name,
        brand: brand,
        model: model,
        chipset: chipset,
        gpuName: gpuName,
        screenSize: screenSize,
        screenResolutionW: resW,
        screenResolutionH: resH,
      ));
    }

    return results;
  }

  static Future<DeviceSearchResult> _fetchNotebookcheckDetail(
      DeviceSearchResult result) async {
    final resp = await http.get(Uri.parse(result.sourceUrl!), headers: {
      'User-Agent': _userAgent,
      'Accept': 'text/html',
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return result;

    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);

    // Extract image and brand from JSON-LD Product data:
    // {"@type": "Product", "name": "...", "brand": {"name": "..."},
    //  "image": {"url": "https://...jpg"}}
    String? imageUrl;
    final jsonLdBlocks = RegExp(
      r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
      dotAll: true,
    ).allMatches(html);
    for (final block in jsonLdBlocks) {
      try {
        final data = jsonDecode(block.group(1)!) as Map<String, dynamic>;
        if (data['@type'] == 'Product') {
          final img = data['image'];
          if (img is Map<String, dynamic>) {
            imageUrl = img['url'] as String?;
          } else if (img is String) {
            imageUrl = img;
          }
          break;
        }
      } catch (_) {
        // Not valid JSON or not a Product — skip
      }
    }

    return result.withDetail(
      imageUrl: imageUrl,
      // Keep the inline specs already parsed from search results
      chipset: result.chipset,
      gpuName: result.gpuName,
      screenSize: result.screenSize,
      screenResolutionW: result.screenResolutionW,
      screenResolutionH: result.screenResolutionH,
    );
  }
}
