import 'dart:convert';
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  // ============ Intel ARK ============
  print('========== INTEL ARK ==========');

  // Test 1: Intel ARK search API (autocomplete)
  print('\n--- Intel ARK Autocomplete API ---');
  await testUrl(
    'https://www.intel.com/content/www/us/en/search.html?ws=text#q=Core%20i5-520M&t=Products',
    'Intel ARK search page',
  );

  // Test 2: Intel ARK direct API endpoint
  print('\n--- Intel ARK API (odata) ---');
  await testUrl(
    "https://odata.intel.com/API/v1_0/Products/Processors()?&\$filter=substringof('Core i5-520M',ProductName)&\$format=json&\$top=5",
    'Intel odata API',
  );

  // Test 3: Intel ARK autocomplete/typeahead
  print('\n--- Intel ARK typeahead ---');
  await testUrl(
    'https://www.intel.com/libs/apps/intel/arksearch/autocomplete?prodName=Core+i5-520M',
    'Intel ARK autocomplete',
  );

  // Test 4: Intel ARK search via Startpage
  print('\n--- Startpage → Intel ARK ---');
  await testStartpage('Core i5-520M site:ark.intel.com', 'Intel ARK via Startpage');

  // Test 5: Try known Intel ARK product page
  print('\n--- Intel ARK product page (known URL) ---');
  await testUrl(
    'https://ark.intel.com/content/www/us/en/ark/products/47341/intel-core-i5-520m-processor-3m-cache-2-40-ghz.html',
    'Intel ARK Core i5-520M page',
    showBody: true,
    bodyLimit: 3000,
  );

  // Test 6: Intel ARK search with different approach
  print('\n--- Intel ARK compare API ---');
  await testUrl(
    'https://ark.intel.com/content/www/us/en/ark/search.html?_charset_=UTF-8&q=Core+i5-520M',
    'Intel ARK search',
  );

  // Test 7: Try ark.intel.com with API headers
  print('\n--- Intel ARK with API-like request ---');
  try {
    final resp = await http.get(
      Uri.parse('https://ark.intel.com/content/www/us/en/ark/search.html?_charset_=UTF-8&q=Core+i5-520M'),
      headers: {
        'User-Agent': ua,
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    ).timeout(const Duration(seconds: 15));
    print('  Status: ${resp.statusCode}');
    print('  Body length: ${resp.body.length}');
    // Look for product links
    final arkLinks = RegExp(r'href="(/content/www/us/en/ark/products/\d+/[^"]+)"')
        .allMatches(resp.body)
        .map((m) => m.group(1))
        .toSet();
    print('  ARK product links found: ${arkLinks.length}');
    for (final link in arkLinks.take(5)) {
      print('    $link');
    }
    // Look for JSON-LD
    final jsonLd = RegExp(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', dotAll: true)
        .allMatches(resp.body);
    print('  JSON-LD blocks: ${jsonLd.length}');
    for (final m in jsonLd) {
      print('    ${m.group(1)!.substring(0, m.group(1)!.length.clamp(0, 200))}');
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ============ AMD ============
  print('\n\n========== AMD ==========');

  // Test 8: AMD product search page
  print('\n--- AMD product search ---');
  await testUrl(
    'https://www.amd.com/en/products/processors/search.html#q=Ryzen%209%207950X',
    'AMD product search page',
  );

  // Test 9: AMD via Startpage
  print('\n--- Startpage → AMD product page ---');
  await testStartpage('Ryzen 9 7950X site:amd.com/en/product', 'AMD Ryzen via Startpage');
  await testStartpage('Ryzen 9 7950X site:amd.com specifications', 'AMD Ryzen specs via Startpage');

  // Test 10: AMD direct product page (guessed URL)
  print('\n--- AMD product page (guessed) ---');
  await testUrl(
    'https://www.amd.com/en/products/processors/desktops/ryzen/7000-series/amd-ryzen-9-7950x.html',
    'AMD Ryzen 9 7950X page (guessed)',
    showBody: true,
    bodyLimit: 3000,
  );

  // Test 11: AMD product API
  print('\n--- AMD product API ---');
  await testUrl(
    'https://www.amd.com/en/resources/product-search.json?q=Ryzen+9+7950X',
    'AMD product JSON API',
  );

  // ============ Qualcomm ============
  print('\n\n========== QUALCOMM ==========');

  // Test 12: Qualcomm Snapdragon specs
  print('\n--- Startpage → Qualcomm Snapdragon ---');
  await testStartpage('Snapdragon 8 Gen 3 specifications site:qualcomm.com', 'Qualcomm via Startpage');

  // ============ NVIDIA ============
  print('\n\n========== NVIDIA ==========');

  // Test 13: NVIDIA product page
  print('\n--- Startpage → NVIDIA RTX 4090 ---');
  await testStartpage('GeForce RTX 4090 specifications site:nvidia.com', 'NVIDIA via Startpage');
}

Future<void> testUrl(String url, String label, {bool showBody = false, int bodyLimit = 500}) async {
  try {
    final resp = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': ua, 'Accept': 'text/html,application/json'},
    ).timeout(const Duration(seconds: 15));
    print('  [$label] Status: ${resp.statusCode}');
    print('  Body length: ${resp.body.length}');
    if (resp.statusCode >= 300 && resp.statusCode < 400) {
      print('  Location: ${resp.headers['location']}');
    }
    if (showBody && resp.body.isNotEmpty) {
      final body = resp.body.length > bodyLimit
          ? resp.body.substring(0, bodyLimit)
          : resp.body;
      print('  Body preview:\n$body');
    }
  } catch (e) {
    print('  [$label] ERROR: $e');
  }
}

Future<void> testStartpage(String query, String label) async {
  try {
    final resp = await http.post(
      Uri.parse('https://www.startpage.com/sp/search'),
      headers: {
        'User-Agent': ua,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'query=${Uri.encodeComponent(query)}',
    ).timeout(const Duration(seconds: 15));
    print('  [$label] Status: ${resp.statusCode}');
    print('  Body length: ${resp.body.length}');

    // Extract URLs matching the site
    final urls = RegExp(r'https?://[^\s"<>]+')
        .allMatches(resp.body)
        .map((m) => m.group(0)!)
        .where((u) {
          final lower = u.toLowerCase();
          return lower.contains('ark.intel.com') ||
                 lower.contains('amd.com/en/product') ||
                 lower.contains('qualcomm.com/snapdragon') ||
                 lower.contains('qualcomm.com/products') ||
                 lower.contains('nvidia.com/en-us/geforce') ||
                 lower.contains('nvidia.com/en-us/data-center');
        })
        .toSet();
    print('  Relevant URLs found: ${urls.length}');
    for (final u in urls.take(10)) {
      print('    $u');
    }
  } catch (e) {
    print('  [$label] ERROR: $e');
  }
}
