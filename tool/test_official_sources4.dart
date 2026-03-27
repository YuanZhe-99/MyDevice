import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  // Test Intel product spec pages (found via Startpage)
  print('========== Intel Core i5-520M Specifications ==========');
  await testIntelProductPage(
    'https://www.intel.com/content/www/us/en/products/sku/52229/intel-core-i52520m-processor-3m-cache-up-to-3-20-ghz/specifications.html',
  );

  print('\n\n========== Intel Core Ultra 7 258V Specifications ==========');
  await testIntelProductPage(
    'https://www.intel.com/content/www/us/en/products/sku/240957/intel-core-ultra-7-processor-258v-12m-cache-up-to-4-80-ghz/specifications.html',
  );

  // Test finding Intel URLs for more CPUs
  print('\n\n========== Startpage: more Intel CPUs ==========');
  await findAndTestIntel('Core i9-14900K');
  await findAndTestIntel('Xeon w9-3595X');
  await findAndTestIntel('Core i7-12700H');

  // Test finding Intel Arc GPU
  print('\n\n========== Intel Arc GPU ==========');
  await findAndTestIntelGpu('Intel Arc A770');
  await findAndTestIntelGpu('Intel Arc B580');
}

Future<void> testIntelProductPage(String url) async {
  print('  URL: $url');
  final client = HttpClient()
    ..badCertificateCallback = (cert, host, port) => host.contains('intel.com');

  try {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set('User-Agent', ua);
    req.headers.set('Accept', 'text/html');
    final resp = await req.close().timeout(const Duration(seconds: 20));
    final body = await resp.transform(utf8.decoder).join();
    print('  Status: ${resp.statusCode}');
    print('  Body length: ${body.length}');

    if (resp.statusCode != 200) {
      // Check redirect
      if (resp.statusCode >= 300 && resp.statusCode < 400) {
        print('  Redirect: ${resp.headers.value('location')}');
      }
      return;
    }

    // Title
    final title = RegExp(r'<title>([^<]+)</title>').firstMatch(body);
    print('  <title>: ${title?.group(1)}');

    // og:meta
    final ogTitle = RegExp(r'<meta\s+property="og:title"\s+content="([^"]+)"').firstMatch(body);
    final ogDesc = RegExp(r'<meta\s+property="og:description"\s+content="([^"]+)"').firstMatch(body);
    print('  og:title: ${ogTitle?.group(1)}');
    print('  og:description: ${ogDesc?.group(1)}');

    // th/td
    final thTd = <String, String>{};
    for (final m in RegExp(r'<th[^>]*>(.*?)</th>\s*<td[^>]*>(.*?)</td>', dotAll: true).allMatches(body)) {
      final key = m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      final val = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (key.isNotEmpty && val.isNotEmpty) thTd[key] = val;
    }
    print('  TH/TD specs: ${thTd.length}');
    for (final e in thTd.entries.take(30)) {
      print('    ${e.key}: ${e.value}');
    }

    // dt/dd
    final dtDd = <String, String>{};
    for (final m in RegExp(r'<dt[^>]*>(.*?)</dt>\s*<dd[^>]*>(.*?)</dd>', dotAll: true).allMatches(body)) {
      final key = m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      final val = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (key.isNotEmpty && val.isNotEmpty) dtDd[key] = val;
    }
    print('  DT/DD specs: ${dtDd.length}');
    for (final e in dtDd.entries.take(30)) {
      print('    ${e.key}: ${e.value}');
    }

    // JSON-LD Product
    for (final m in RegExp(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', dotAll: true).allMatches(body)) {
      try {
        final data = jsonDecode(m.group(1)!.trim());
        if (data is Map && data['@type'] == 'Product') {
          print('  JSON-LD Product found!');
          print('    name: ${data['name']}');
          print('    description: ${data['description']?.toString().substring(0, (data['description']?.toString().length ?? 0).clamp(0, 300))}');
          if (data['additionalProperty'] != null) {
            final props = data['additionalProperty'] as List;
            print('    additionalProperty: ${props.length} items');
            for (final p in props.take(30)) {
              print('      ${p['name']}: ${p['value']}');
            }
          }
        }
      } catch (_) {}
    }

    // Check for noscript
    print('  Has <noscript>: ${body.contains('<noscript')}');

    // Look for spec-related patterns
    final specDivs = RegExp(r'class="[^"]*(?:spec|product-detail|feature)[^"]*"', caseSensitive: false)
        .allMatches(body)
        .map((m) => m.group(0)!)
        .toSet();
    print('  Spec-related classes: ${specDivs.length}');
    for (final s in specDivs.take(15)) print('    $s');

  } catch (e) {
    print('  ERROR: $e');
  } finally {
    client.close();
  }
}

Future<void> findAndTestIntel(String query) async {
  print('\n--- $query ---');
  final resp = await http.post(
    Uri.parse('https://www.startpage.com/sp/search'),
    headers: {
      'User-Agent': ua,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'query=${Uri.encodeComponent("$query specifications site:intel.com/content/www/us/en/products")}',
  ).timeout(const Duration(seconds: 15));

  if (resp.statusCode != 200) {
    print('  Startpage failed: ${resp.statusCode}');
    return;
  }

  final urls = RegExp(r'https?://www\.intel\.com/content/www/us/en/products/sku/\d+/[^\s"<>&\\]+/specifications\.html')
      .allMatches(resp.body)
      .map((m) => m.group(0)!)
      .toSet();
  print('  Intel spec URLs: ${urls.length}');
  for (final u in urls.take(3)) print('    $u');

  if (urls.isNotEmpty) {
    await testIntelProductPage(urls.first);
  } else {
    // Try broader match
    final broader = RegExp(r'https?://www\.intel\.com/content/www/us/en/products/sku/\d+/[^\s"<>&\\]+\.html')
        .allMatches(resp.body)
        .map((m) => m.group(0)!)
        .toSet();
    print('  Broader Intel URLs: ${broader.length}');
    for (final u in broader.take(5)) print('    $u');
  }
}

Future<void> findAndTestIntelGpu(String query) async {
  print('\n--- $query ---');
  final resp = await http.post(
    Uri.parse('https://www.startpage.com/sp/search'),
    headers: {
      'User-Agent': ua,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'query=${Uri.encodeComponent("$query specifications site:intel.com/content/www/us/en/products")}',
  ).timeout(const Duration(seconds: 15));

  if (resp.statusCode != 200) return;

  final urls = RegExp(r'https?://www\.intel\.com/content/www/us/en/products/sku/\d+/[^\s"<>&\\]+\.html')
      .allMatches(resp.body)
      .map((m) => m.group(0)!)
      .toSet();
  print('  Intel URLs: ${urls.length}');
  for (final u in urls.take(5)) print('    $u');

  // Find spec URL
  final specUrl = urls.firstWhere(
    (u) => u.contains('/specifications.html'),
    orElse: () => urls.isNotEmpty ? urls.first : '',
  );
  if (specUrl.isNotEmpty) {
    await testIntelProductPage(specUrl);
  }
}
