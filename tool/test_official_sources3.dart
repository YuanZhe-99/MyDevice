import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  // ========== INTEL: Startpage → ARK product page ==========
  print('========== Intel ARK via Startpage ==========');

  print('\n--- Core i5-520M ---');
  await testIntelViaStartpage('Core i5-520M');

  print('\n--- Core Ultra 7 258V ---');
  await testIntelViaStartpage('Core Ultra 7 258V');

  print('\n--- Core i9-14900K ---');
  await testIntelViaStartpage('Core i9-14900K');

  print('\n--- Xeon w9-3595X ---');
  await testIntelViaStartpage('Xeon w9-3595X');

  // ========== INTEL: Try alternate intel.com pages ==========
  print('\n\n========== Intel product pages (non-ARK) ==========');
  print('\n--- Startpage → intel.com product ---');
  await testStartpageIntel('Core i5-520M specifications site:intel.com');
  await testStartpageIntel('Core Ultra 7 258V specifications site:intel.com');

  // ========== AMD: More GPU tests ==========
  print('\n\n========== AMD GPU: Radeon RX 9070 XT ==========');
  await testAmdViaStartpage('Radeon RX 9070 XT', 'graphics');

  print('\n\n========== AMD CPU: EPYC 9654 ==========');
  await testAmdViaStartpage('EPYC 9654', 'processors');
}

Future<void> testIntelViaStartpage(String query) async {
  // Step 1: Find ARK URL via Startpage
  final resp = await http.post(
    Uri.parse('https://www.startpage.com/sp/search'),
    headers: {
      'User-Agent': ua,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'query=${Uri.encodeComponent("$query site:ark.intel.com")}',
  ).timeout(const Duration(seconds: 15));

  if (resp.statusCode != 200) {
    print('  Startpage failed: ${resp.statusCode}');
    return;
  }

  // Find ARK product URLs
  final urls = RegExp(r'https?://ark\.intel\.com/content/www/us/en/ark/products/\d+/[^\s"<>&\\]+\.html')
      .allMatches(resp.body)
      .map((m) => m.group(0)!)
      .toSet();
  print('  ARK URLs from Startpage: ${urls.length}');
  for (final u in urls.take(5)) print('    $u');

  if (urls.isEmpty) {
    print('  No ARK URL found');
    return;
  }

  // Step 2: Fetch ARK product page with SSL bypass
  final arkUrl = urls.first;
  print('  Fetching: $arkUrl');
  final client = HttpClient()
    ..badCertificateCallback = (cert, host, port) => host.contains('intel.com');

  try {
    final req = await client.getUrl(Uri.parse(arkUrl));
    req.headers.set('User-Agent', ua);
    req.headers.set('Accept', 'text/html');
    final arkResp = await req.close().timeout(const Duration(seconds: 15));
    final body = await arkResp.transform(utf8.decoder).join();
    print('  Status: ${arkResp.statusCode}');
    print('  Body length: ${body.length}');

    if (arkResp.statusCode != 200) return;

    // Check <title>
    final title = RegExp(r'<title>([^<]+)</title>').firstMatch(body);
    print('  <title>: ${title?.group(1)}');

    // og:meta
    final ogTitle = RegExp(r'<meta\s+property="og:title"\s+content="([^"]+)"').firstMatch(body);
    final ogDesc = RegExp(r'<meta\s+property="og:description"\s+content="([^"]+)"').firstMatch(body);
    print('  og:title: ${ogTitle?.group(1)}');
    print('  og:description: ${ogDesc?.group(1)}');

    // Look for ark-data-name / ark-data-value
    final arkSpecs = <String, String>{};
    for (final m in RegExp(
      r'<span[^>]*class="[^"]*ark-data-name[^"]*"[^>]*>(.*?)</span>.*?<span[^>]*class="[^"]*ark-data-value[^"]*"[^>]*>(.*?)</span>',
      dotAll: true,
    ).allMatches(body)) {
      final key = m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      final val = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (key.isNotEmpty && val.isNotEmpty) arkSpecs[key] = val;
    }
    print('  ARK specs (ark-data-name/value): ${arkSpecs.length}');
    for (final e in arkSpecs.entries.take(25)) {
      print('    ${e.key}: ${e.value}');
    }

    // Try th/td
    final thTd = <String, String>{};
    for (final m in RegExp(r'<th[^>]*>(.*?)</th>\s*<td[^>]*>(.*?)</td>', dotAll: true).allMatches(body)) {
      final key = m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      final val = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (key.isNotEmpty && val.isNotEmpty) thTd[key] = val;
    }
    print('  TH/TD specs: ${thTd.length}');
    for (final e in thTd.entries.take(25)) {
      print('    ${e.key}: ${e.value}');
    }

    // Try dt/dd
    final dtDd = <String, String>{};
    for (final m in RegExp(r'<dt[^>]*>(.*?)</dt>\s*<dd[^>]*>(.*?)</dd>', dotAll: true).allMatches(body)) {
      final key = m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      final val = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (key.isNotEmpty && val.isNotEmpty) dtDd[key] = val;
    }
    print('  DT/DD specs: ${dtDd.length}');
    for (final e in dtDd.entries.take(25)) {
      print('    ${e.key}: ${e.value}');
    }

    // JSON-LD
    final jsonLd = RegExp(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', dotAll: true)
        .allMatches(body);
    print('  JSON-LD blocks: ${jsonLd.length}');
    for (final m in jsonLd) {
      final j = m.group(1)!.trim();
      try {
        final data = jsonDecode(j);
        if (data is Map) {
          print('    @type: ${data['@type']}');
          if (data.containsKey('name')) print('    name: ${data['name']}');
          if (data.containsKey('description')) {
            print('    description: ${data['description'].toString().substring(0, data['description'].toString().length.clamp(0, 200))}');
          }
        }
      } catch (_) {
        print('    (first 300): ${j.substring(0, j.length.clamp(0, 300))}');
      }
    }

    // Check for noscript
    final noscript = body.contains('<noscript');
    print('  Has <noscript>: $noscript');

    // Check for data attributes with spec info
    final dataAttrs = RegExp(r'data-(?:key|spec|product|value)="([^"]+)"')
        .allMatches(body)
        .map((m) => '${m.group(0)}')
        .take(20)
        .toList();
    print('  Data attributes (first 20): ${dataAttrs.length}');
    for (final a in dataAttrs) print('    $a');

  } catch (e) {
    print('  ERROR: $e');
  } finally {
    client.close();
  }
}

Future<void> testStartpageIntel(String query) async {
  final resp = await http.post(
    Uri.parse('https://www.startpage.com/sp/search'),
    headers: {
      'User-Agent': ua,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'query=${Uri.encodeComponent(query)}',
  ).timeout(const Duration(seconds: 15));

  final urls = RegExp(r'https?://(?:www\.)?intel\.com/[^\s"<>&\\]+')
      .allMatches(resp.body)
      .map((m) => m.group(0)!)
      .where((u) => u.contains('product') || u.contains('ark') || u.contains('spec'))
      .toSet();
  print('  Query: $query');
  print('  Intel URLs found: ${urls.length}');
  for (final u in urls.take(10)) print('    $u');
}

Future<void> testAmdViaStartpage(String query, String category) async {
  final resp = await http.post(
    Uri.parse('https://www.startpage.com/sp/search'),
    headers: {
      'User-Agent': ua,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'query=${Uri.encodeComponent("$query specifications site:amd.com/en/products")}',
  ).timeout(const Duration(seconds: 15));

  if (resp.statusCode != 200) {
    print('  Startpage failed: ${resp.statusCode}');
    return;
  }

  final urls = RegExp(r'https?://www\.amd\.com/en/products/[^\s"<>&\\]+\.html')
      .allMatches(resp.body)
      .map((m) => m.group(0)!)
      .where((u) => !u.endsWith(r'\'))
      .toSet();
  print('  AMD URLs: ${urls.length}');
  for (final u in urls.take(5)) print('    $u');

  if (urls.isEmpty) return;

  final amdUrl = urls.first;
  print('  Fetching: $amdUrl');
  final amdResp = await http.get(
    Uri.parse(amdUrl),
    headers: {'User-Agent': ua, 'Accept': 'text/html'},
  ).timeout(const Duration(seconds: 20));

  if (amdResp.statusCode != 200) {
    print('  Status: ${amdResp.statusCode}');
    return;
  }

  final html = utf8.decode(amdResp.bodyBytes, allowMalformed: true);

  // DT/DD specs
  final dtDd = <String, String>{};
  for (final m in RegExp(r'<dt[^>]*>(.*?)</dt>\s*<dd[^>]*>(.*?)</dd>', dotAll: true).allMatches(html)) {
    final key = m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final val = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (key.isNotEmpty && val.isNotEmpty) dtDd[key] = val;
  }
  print('  DT/DD specs: ${dtDd.length}');
  for (final e in dtDd.entries.take(30)) {
    print('    ${e.key}: ${e.value}');
  }
}
