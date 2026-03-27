import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  // ========== AMD PRODUCT PAGE (works!) ==========
  print('========== AMD Ryzen 9 7950X ==========');
  await testAmdPage(
    'https://www.amd.com/en/products/processors/desktops/ryzen/7000-series/amd-ryzen-9-7950x.html',
  );

  print('\n========== AMD Ryzen 5 5600X ==========');
  // Find URL via Startpage first
  final r5600xUrl = await findAmdUrl('Ryzen 5 5600X');
  if (r5600xUrl != null) await testAmdPage(r5600xUrl);

  print('\n========== AMD Ryzen 9 9950X ==========');
  final r9950xUrl = await findAmdUrl('Ryzen 9 9950X');
  if (r9950xUrl != null) await testAmdPage(r9950xUrl);

  // ========== NVIDIA PRODUCT PAGE ==========
  print('\n\n========== NVIDIA RTX 4090 ==========');
  await testNvidiaPage(
    'https://www.nvidia.com/en-us/geforce/graphics-cards/40-series/rtx-4090/',
  );

  // ========== INTEL ARK (with SSL workaround) ==========
  print('\n\n========== INTEL ARK (HttpClient with badCertificate) ==========');
  await testIntelArk('Core i5-520M');
  await testIntelArk('Core Ultra 7 258V');

  // ========== AMD GPU ==========
  print('\n\n========== AMD Radeon RX 7900 XTX ==========');
  final rx7900Url = await findAmdUrl('Radeon RX 7900 XTX');
  if (rx7900Url != null) {
    await testAmdPage(rx7900Url);
  } else {
    print('  No AMD URL found');
  }
}

Future<String?> findAmdUrl(String query) async {
  print('  Searching Startpage for AMD URL...');
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
    return null;
  }

  final match = RegExp(
    r'https?://www\.amd\.com/en/products/[^\s"<>&\\]+\.html',
  ).allMatches(resp.body).map((m) => m.group(0)!).where((u) => !u.endsWith(r'\')).toSet();
  print('  AMD URLs found: ${match.length}');
  for (final u in match.take(5)) print('    $u');
  return match.isNotEmpty ? match.first : null;
}

Future<void> testAmdPage(String url) async {
  print('  URL: $url');
  try {
    final resp = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 20));
    print('  Status: ${resp.statusCode}');
    if (resp.statusCode != 200) return;

    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    print('  Body length: ${html.length}');

    // Check og:title & og:description
    final ogTitle = RegExp(r'<meta\s+property="og:title"\s+content="([^"]+)"').firstMatch(html);
    final ogDesc = RegExp(r'<meta\s+property="og:description"\s+content="([^"]+)"').firstMatch(html);
    print('  og:title: ${ogTitle?.group(1)}');
    print('  og:description: ${ogDesc?.group(1)}');

    // Check <title>
    final title = RegExp(r'<title>([^<]+)</title>').firstMatch(html);
    print('  <title>: ${title?.group(1)}');

    // Look for spec table - check data-spec attributes
    final dataSpecs = RegExp(r'data-spec="([^"]+)"').allMatches(html).map((m) => m.group(1)!).toSet();
    print('  data-spec attrs: ${dataSpecs.length}');
    for (final s in dataSpecs.take(20)) print('    $s');

    // Look for th/td pairs
    final thTd = <String, String>{};
    for (final m in RegExp(r'<th[^>]*>(.*?)</th>\s*<td[^>]*>(.*?)</td>', dotAll: true).allMatches(html)) {
      final key = m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      final val = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (key.isNotEmpty && val.isNotEmpty) thTd[key] = val;
    }
    print('  TH/TD specs: ${thTd.length}');
    for (final e in thTd.entries.take(30)) {
      print('    ${e.key}: ${e.value}');
    }

    // Look for dt/dd pairs
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

    // Look for JSON-LD
    final jsonLdBlocks = RegExp(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', dotAll: true)
        .allMatches(html);
    print('  JSON-LD blocks: ${jsonLdBlocks.length}');
    for (final m in jsonLdBlocks) {
      final jsonStr = m.group(1)!.trim();
      try {
        final data = jsonDecode(jsonStr);
        if (data is Map) {
          print('    @type: ${data['@type']}');
          if (data['@type'] == 'Product') {
            print('    name: ${data['name']}');
            print('    description: ${data['description']?.toString().substring(0, 200.clamp(0, (data['description']?.toString().length ?? 0)))}');
          }
        }
      } catch (_) {
        print('    (parse error, first 200 chars): ${jsonStr.substring(0, jsonStr.length.clamp(0, 200))}');
      }
    }

    // Look for spec-like CSS classes
    final specClasses = RegExp(r'class="[^"]*spec[^"]*"', caseSensitive: false)
        .allMatches(html)
        .map((m) => m.group(0)!)
        .toSet();
    print('  Spec-related classes: ${specClasses.length}');
    for (final c in specClasses.take(10)) print('    $c');

    // Look for product-specifications or similar sections
    final specSections = RegExp(r'id="([^"]*spec[^"]*)"', caseSensitive: false)
        .allMatches(html)
        .map((m) => m.group(1)!)
        .toSet();
    print('  Spec section IDs: ${specSections.length}');
    for (final s in specSections) print('    $s');

  } catch (e) {
    print('  ERROR: $e');
  }
}

Future<void> testNvidiaPage(String url) async {
  print('  URL: $url');
  try {
    final resp = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 20));
    print('  Status: ${resp.statusCode}');
    if (resp.statusCode != 200) return;

    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    print('  Body length: ${html.length}');

    // og:meta
    final ogTitle = RegExp(r'<meta\s+property="og:title"\s+content="([^"]+)"').firstMatch(html);
    final ogDesc = RegExp(r'<meta\s+property="og:description"\s+content="([^"]+)"').firstMatch(html);
    print('  og:title: ${ogTitle?.group(1)}');
    print('  og:description: ${ogDesc?.group(1)}');

    // th/td
    final thTd = <String, String>{};
    for (final m in RegExp(r'<th[^>]*>(.*?)</th>\s*<td[^>]*>(.*?)</td>', dotAll: true).allMatches(html)) {
      final key = m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      final val = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (key.isNotEmpty && val.isNotEmpty) thTd[key] = val;
    }
    print('  TH/TD specs: ${thTd.length}');
    for (final e in thTd.entries) {
      print('    ${e.key}: ${e.value}');
    }

    // JSON-LD
    final jsonLdBlocks = RegExp(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', dotAll: true)
        .allMatches(html);
    print('  JSON-LD blocks: ${jsonLdBlocks.length}');
    for (final m in jsonLdBlocks) {
      final jsonStr = m.group(1)!.trim();
      try {
        final data = jsonDecode(jsonStr);
        if (data is Map) {
          print('    @type: ${data['@type']}');
        }
      } catch (_) {}
    }

    // Spec classes
    final specSections = RegExp(r'id="([^"]*spec[^"]*)"', caseSensitive: false)
        .allMatches(html)
        .map((m) => m.group(1)!)
        .toSet();
    print('  Spec section IDs: ${specSections.length}');
    for (final s in specSections) print('    $s');

  } catch (e) {
    print('  ERROR: $e');
  }
}

Future<void> testIntelArk(String query) async {
  print('\n  --- Intel ARK: $query ---');
  // Use dart:io HttpClient to bypass SSL cert issues
  final client = HttpClient()
    ..badCertificateCallback = (cert, host, port) => host.contains('intel.com');

  try {
    // Try search page
    final searchUrl = 'https://ark.intel.com/content/www/us/en/ark/search.html?_charset_=UTF-8&q=${Uri.encodeComponent(query)}';
    final req = await client.getUrl(Uri.parse(searchUrl));
    req.headers.set('User-Agent', ua);
    req.headers.set('Accept', 'text/html');
    final resp = await req.close().timeout(const Duration(seconds: 15));
    final body = await resp.transform(utf8.decoder).join();
    print('  Status: ${resp.statusCode}');
    print('  Body length: ${body.length}');

    if (resp.statusCode >= 300 && resp.statusCode < 400) {
      print('  Redirect: ${resp.headers.value('location')}');
    }

    // Check for product links
    final arkLinks = RegExp(r'href="(/content/www/us/en/ark/products/\d+/[^"]+\.html)"')
        .allMatches(body)
        .map((m) => m.group(1)!)
        .toSet();
    print('  ARK product links: ${arkLinks.length}');
    for (final l in arkLinks.take(5)) print('    $l');

    // If redirected to a product page, check for specs
    if (arkLinks.isEmpty) {
      // Maybe it's already a product page
      final thTd = <String, String>{};
      for (final m in RegExp(r'<span class="ark-data-name"[^>]*>([^<]+)</span>.*?<span class="ark-data-value"[^>]*>(.*?)</span>', dotAll: true).allMatches(body)) {
        final key = m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
        final val = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
        if (key.isNotEmpty && val.isNotEmpty) thTd[key] = val;
      }
      print('  Intel ARK specs: ${thTd.length}');
      for (final e in thTd.entries.take(20)) {
        print('    ${e.key}: ${e.value}');
      }

      // Also check for data-key attributes
      final dataKeys = RegExp(r'data-key="([^"]+)"').allMatches(body).map((m) => m.group(1)!).toSet();
      print('  data-key attrs: ${dataKeys.length}');
      for (final k in dataKeys.take(20)) print('    $k');

      // Check JSON-LD
      final jsonLd = RegExp(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', dotAll: true)
          .allMatches(body);
      print('  JSON-LD: ${jsonLd.length}');
      for (final m in jsonLd) {
        final j = m.group(1)!.trim();
        print('    ${j.substring(0, j.length.clamp(0, 300))}');
      }
    } else {
      // Follow first product link
      final productUrl = 'https://ark.intel.com${arkLinks.first}';
      print('  Following: $productUrl');
      final req2 = await client.getUrl(Uri.parse(productUrl));
      req2.headers.set('User-Agent', ua);
      req2.headers.set('Accept', 'text/html');
      final resp2 = await req2.close().timeout(const Duration(seconds: 15));
      final body2 = await resp2.transform(utf8.decoder).join();
      print('  Product page status: ${resp2.statusCode}');
      print('  Product page length: ${body2.length}');

      // Parse specs
      final specs = <String, String>{};
      for (final m in RegExp(r'<span class="ark-data-name"[^>]*>([^<]+)</span>.*?<span class="ark-data-value"[^>]*>(.*?)</span>', dotAll: true).allMatches(body2)) {
        final key = m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
        final val = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
        if (key.isNotEmpty && val.isNotEmpty) specs[key] = val;
      }
      print('  Specs: ${specs.length}');
      for (final e in specs.entries.take(20)) {
        print('    ${e.key}: ${e.value}');
      }

      // data-key
      final dataKeys2 = RegExp(r'data-key="([^"]+)"').allMatches(body2).map((m) => m.group(1)!).toSet();
      print('  data-key: ${dataKeys2.length}');
      for (final k in dataKeys2.take(20)) print('    $k');
    }
  } catch (e) {
    print('  ERROR: $e');
  } finally {
    client.close();
  }
}
