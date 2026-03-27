import 'dart:convert';
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/// Test all online chip search sources: TechPowerUp, AMD, Intel.
Future<void> main() async {
  // ======== CPU Tests ========
  print('=== CPU: Core i5 520M (Intel - expect TechPowerUp + Intel) ===');
  await testCpuTechPowerUp('Core i5 520M');
  await testCpuIntel('Core i5 520M');

  print('\n=== CPU: Ryzen 9 7950X (AMD - expect TechPowerUp + AMD) ===');
  await testCpuTechPowerUp('Ryzen 9 7950X');
  await testCpuAmd('Ryzen 9 7950X');

  print('\n=== CPU: Core i9-14900K (Intel - expect TechPowerUp + Intel) ===');
  await testCpuTechPowerUp('Core i9-14900K');
  await testCpuIntel('Core i9-14900K');

  print('\n=== CPU: Ryzen 9 9950X (AMD - expect TechPowerUp + AMD) ===');
  await testCpuTechPowerUp('Ryzen 9 9950X');
  await testCpuAmd('Ryzen 9 9950X');

  // ======== GPU Tests ========
  print('\n=== GPU: RTX 4090 (NVIDIA - expect TechPowerUp only) ===');
  await testGpuTechPowerUp('RTX 4090');

  print('\n=== GPU: Radeon RX 7900 XTX (AMD - expect TechPowerUp + AMD) ===');
  await testGpuTechPowerUp('Radeon RX 7900 XTX');
  await testGpuAmd('Radeon RX 7900 XTX');

  print('\n=== GPU: Radeon RX 9070 XT (AMD - expect TechPowerUp + AMD) ===');
  await testGpuTechPowerUp('Radeon RX 9070 XT');
  await testGpuAmd('Radeon RX 9070 XT');
}

// ──── TechPowerUp CPU ────
Future<void> testCpuTechPowerUp(String query) async {
  print('  [TechPowerUp]');
  try {
    final tpuUrl = await findTpuUrl(query, 'cpu-specs');
    if (tpuUrl == null) { print('    No URL found'); return; }
    final resp = await http.get(Uri.parse(tpuUrl),
      headers: {'User-Agent': ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) { print('    Status: ${resp.statusCode}'); return; }
    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    final title = RegExp(r'<title>([^<|]+)').firstMatch(html)?.group(1)?.trim()?.replaceAll(RegExp(r'\s*Specs$'), '');
    print('    Model: $title');
    print('    URL: $tpuUrl');
    print('    OK');
  } catch (e) { print('    ERROR: $e'); }
}

// ──── TechPowerUp GPU ────
Future<void> testGpuTechPowerUp(String query) async {
  print('  [TechPowerUp]');
  try {
    final tpuUrl = await findTpuUrl(query, 'gpu-specs');
    if (tpuUrl == null) { print('    No URL found'); return; }
    final resp = await http.get(Uri.parse(tpuUrl),
      headers: {'User-Agent': ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) { print('    Status: ${resp.statusCode}'); return; }
    final ogTitle = RegExp(r'<meta[^>]*property="og:title"[^>]*content="([^"]+)"').firstMatch(resp.body);
    final ogDesc = RegExp(r'<meta[^>]*property="og:description"[^>]*content="([^"]+)"').firstMatch(resp.body);
    print('    Model: ${ogTitle?.group(1)?.replaceAll(RegExp(r'\s*Specs$'), '')}');
    print('    Chip: ${ogDesc?.group(1)?.split(', ').first}');
    print('    URL: $tpuUrl');
    print('    OK');
  } catch (e) { print('    ERROR: $e'); }
}

// ──── AMD CPU ────
Future<void> testCpuAmd(String query) async {
  print('  [AMD]');
  try {
    final url = await findAmdUrl(query, 'processors');
    if (url == null) { print('    No URL found'); return; }
    final resp = await http.get(Uri.parse(url),
      headers: {'User-Agent': ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) { print('    Status: ${resp.statusCode}'); return; }
    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    final specs = parseAmdSpecs(html);
    print('    Model: ${specs['Name']}');
    print('    Architecture: ${specs['Processor Architecture'] ?? specs['Former Codename']}');
    print('    Cores: ${specs['# of CPU Cores']}');
    print('    Threads: ${specs['# of Threads']}');
    print('    Base: ${specs['Base Clock']}');
    print('    Boost: ${specs['Max. Boost Clock']}');
    print('    L2: ${specs['L2 Cache']}  L3: ${specs['L3 Cache']}');
    print('    URL: $url');
    print('    OK');
  } catch (e) { print('    ERROR: $e'); }
}

// ──── AMD GPU ────
Future<void> testGpuAmd(String query) async {
  print('  [AMD]');
  try {
    final url = await findAmdUrl(query, 'graphics');
    if (url == null) { print('    No URL found'); return; }
    final resp = await http.get(Uri.parse(url),
      headers: {'User-Agent': ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) { print('    Status: ${resp.statusCode}'); return; }
    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    final specs = parseAmdSpecs(html);
    print('    Model: ${specs['Name']}');
    print('    Architecture: ${specs['GPU Architecture']}');
    print('    Stream Processors: ${specs['Stream Processors']}');
    print('    Memory: ${specs['Max Memory Size']} ${specs['Memory Type']}');
    print('    URL: $url');
    print('    OK');
  } catch (e) { print('    ERROR: $e'); }
}

// ──── Intel CPU (URL slug) ────
Future<void> testCpuIntel(String query) async {
  print('  [Intel]');
  try {
    final resp = await http.post(
      Uri.parse('https://www.startpage.com/sp/search'),
      headers: {
        'User-Agent': ua,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'query=${Uri.encodeComponent("$query specifications site:intel.com/content/www/us/en/products/sku")}',
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) { print('    Startpage failed'); return; }

    final urlMatch = RegExp(
      r'https?://www\.intel\.com/content/www/us/en/products/sku/\d+/([^\s"<>&\\]+?)/specifications\.html',
    ).firstMatch(resp.body);
    if (urlMatch == null) { print('    No URL found'); return; }

    final specUrl = urlMatch.group(0)!;
    final slug = urlMatch.group(1)!;
    var nameSlug = slug.replaceAll(RegExp(r'-\d+m-cache.*'), '');
    var model = nameSlug.split('-').map((w) => w == 'intel' ? 'Intel' : w == 'processor' ? '' : w)
        .where((w) => w.isNotEmpty).join(' ');
    final cacheMatch = RegExp(r'(\d+)m-cache').firstMatch(slug);
    final freqMatch = RegExp(r'up-to-(\d+)-(\d+)-ghz').firstMatch(slug);
    print('    Model: $model');
    print('    Cache: ${cacheMatch != null ? "${cacheMatch.group(1)} MB" : "N/A"}');
    print('    Max Freq: ${freqMatch != null ? "${freqMatch.group(1)}.${freqMatch.group(2)} GHz" : "N/A"}');
    print('    URL: $specUrl');
    print('    OK');
  } catch (e) { print('    ERROR: $e'); }
}

// ──── Helpers ────
Future<String?> findTpuUrl(String query, String section) async {
  final resp = await http.post(
    Uri.parse('https://www.startpage.com/sp/search'),
    headers: {'User-Agent': ua, 'Content-Type': 'application/x-www-form-urlencoded'},
    body: 'query=${Uri.encodeComponent("$query site:techpowerup.com/$section")}',
  ).timeout(const Duration(seconds: 15));
  if (resp.statusCode != 200) return null;
  return RegExp('https?://www\\.techpowerup\\.com/$section/[^\\s"&<]+\\.c\\d+')
      .firstMatch(resp.body)?.group(0);
}

Future<String?> findAmdUrl(String query, String category) async {
  final resp = await http.post(
    Uri.parse('https://www.startpage.com/sp/search'),
    headers: {'User-Agent': ua, 'Content-Type': 'application/x-www-form-urlencoded'},
    body: 'query=${Uri.encodeComponent("$query specifications site:amd.com/en/products/$category")}',
  ).timeout(const Duration(seconds: 15));
  if (resp.statusCode != 200) return null;
  final match = RegExp(r'https?://www\.amd\.com/en/products/[^\s"<>&\\]+\.html')
      .allMatches(resp.body).map((m) => m.group(0)!).where((u) => !u.endsWith(r'\')).toSet();
  return match.isNotEmpty ? match.first : null;
}

Map<String, String> parseAmdSpecs(String html) {
  final specs = <String, String>{};
  for (final m in RegExp(r'<dt[^>]*>(.*?)</dt>\s*<dd[^>]*>(.*?)</dd>', dotAll: true).allMatches(html)) {
    var key = m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final val = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (key.isEmpty || val.isEmpty) continue;
    for (final marker in [' Max boost ', ' Represents ', ' Boost Clock Frequency ', " 'Game Frequency'", ' AMD`s product warranty', ' EPYC-', ' All-core boost']) {
      final idx = key.indexOf(marker);
      if (idx > 0) { key = key.substring(0, idx); break; }
    }
    specs[key] = val;
  }
  return specs;
}
