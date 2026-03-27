import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  final url = 'https://www.intel.com/content/www/us/en/products/sku/236773/intel-core-i9-processor-14900k-36m-cache-up-to-6-00-ghz/specifications.html';

  // Attempt 1: Full browser-like headers
  print('=== Attempt 1: Full browser headers ===');
  final client1 = HttpClient()
    ..badCertificateCallback = (cert, host, port) => host.contains('intel.com');
  try {
    final req = await client1.getUrl(Uri.parse(url));
    req.headers.set('User-Agent', ua);
    req.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8');
    req.headers.set('Accept-Language', 'en-US,en;q=0.5');
    req.headers.set('Accept-Encoding', 'gzip, deflate, br');
    req.headers.set('Sec-Fetch-Dest', 'document');
    req.headers.set('Sec-Fetch-Mode', 'navigate');
    req.headers.set('Sec-Fetch-Site', 'none');
    req.headers.set('Sec-Fetch-User', '?1');
    req.headers.set('Connection', 'keep-alive');
    req.headers.set('Upgrade-Insecure-Requests', '1');
    final resp = await req.close().timeout(const Duration(seconds: 15));
    final body = await resp.transform(utf8.decoder).join();
    print('  Status: ${resp.statusCode}');
    print('  Body length: ${body.length}');
    print('  Headers: ${resp.headers}');
  } catch (e) {
    print('  ERROR: $e');
  } finally {
    client1.close();
  }

  // Attempt 2: Without /specifications.html (main product page)
  print('\n=== Attempt 2: Main product page (no /specifications) ===');
  final mainUrl = url.replaceAll('/specifications.html', '.html');
  final client2 = HttpClient()
    ..badCertificateCallback = (cert, host, port) => host.contains('intel.com');
  try {
    final req = await client2.getUrl(Uri.parse(mainUrl));
    req.headers.set('User-Agent', ua);
    req.headers.set('Accept', 'text/html');
    final resp = await req.close().timeout(const Duration(seconds: 15));
    final body = await resp.transform(utf8.decoder).join();
    print('  URL: $mainUrl');
    print('  Status: ${resp.statusCode}');
    print('  Body length: ${body.length}');
  } catch (e) {
    print('  ERROR: $e');
  } finally {
    client2.close();
  }

  // Attempt 3: Google cache
  print('\n=== Attempt 3: Startpage cache/snippets for Intel ===');
  try {
    final resp = await http.post(
      Uri.parse('https://www.startpage.com/sp/search'),
      headers: {
        'User-Agent': ua,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'query=${Uri.encodeComponent("Core i9-14900K specifications site:intel.com/content/www/us/en/products")}',
    ).timeout(const Duration(seconds: 15));
    print('  Status: ${resp.statusCode}');
    // Extract snippets around Intel URLs
    final snippets = RegExp(
      r'<p[^>]*class="[^"]*result[^"]*"[^>]*>(.*?)</p>',
      dotAll: true,
    ).allMatches(resp.body).map((m) => m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim()).toList();
    print('  Snippets: ${snippets.length}');
    for (final s in snippets.take(5)) {
      print('    ${s.substring(0, s.length.clamp(0, 200))}');
    }

    // Extract any text around Intel spec URLs that might have numbers
    final intelBlocks = RegExp(
      r'intel-core-i9-processor-14900k[^<]*',
    ).allMatches(resp.body).map((m) => m.group(0)!).toList();
    print('  Intel URL context blocks: ${intelBlocks.length}');
    for (final b in intelBlocks.take(5)) {
      print('    $b');
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // Attempt 4: Extract info from URL slug
  print('\n=== Attempt 4: Parse URL slug for spec data ===');
  final testUrls = [
    'https://www.intel.com/content/www/us/en/products/sku/236773/intel-core-i9-processor-14900k-36m-cache-up-to-6-00-ghz/specifications.html',
    'https://www.intel.com/content/www/us/en/products/sku/240957/intel-core-ultra-7-processor-258v-12m-cache-up-to-4-80-ghz/specifications.html',
    'https://www.intel.com/content/www/us/en/products/sku/52229/intel-core-i52520m-processor-3m-cache-up-to-3-20-ghz/specifications.html',
    'https://www.intel.com/content/www/us/en/products/sku/132228/intel-core-i712700h-processor-24m-cache-up-to-4-70-ghz/specifications.html',
  ];
  for (final u in testUrls) {
    final slug = RegExp(r'/sku/\d+/(.*?)/').firstMatch(u)?.group(1) ?? '';
    // Parse model name: intel-core-i9-processor-14900k → Intel Core i9 Processor 14900K
    var name = slug.replaceAll(RegExp(r'-\d+m-cache.*'), '');
    name = name.replaceAll('-', ' ');
    // Extract cache
    final cache = RegExp(r'(\d+)m-cache').firstMatch(slug)?.group(1);
    // Extract max freq
    final freq = RegExp(r'up-to-(\d+)-(\d+)-ghz').firstMatch(slug);
    final maxFreq = freq != null ? '${freq.group(1)}.${freq.group(2)} GHz' : null;
    print('  $slug');
    print('    Name: $name');
    print('    Cache: ${cache != null ? "${cache} MB" : "N/A"}');
    print('    Max Freq: ${maxFreq ?? "N/A"}');
  }

  // Attempt 5: Try Intel API endpoint directly
  print('\n=== Attempt 5: Intel product API ===');
  final client5 = HttpClient()
    ..badCertificateCallback = (cert, host, port) => host.contains('intel.com');
  try {
    // Try the product comparison API
    final apiUrl = 'https://www.intel.com/content/www/us/en/products/compare.html?productIds=236773';
    final req = await client5.getUrl(Uri.parse(apiUrl));
    req.headers.set('User-Agent', ua);
    req.headers.set('Accept', 'application/json, text/html');
    final resp = await req.close().timeout(const Duration(seconds: 15));
    final body = await resp.transform(utf8.decoder).join();
    print('  Compare API status: ${resp.statusCode}');
    print('  Body length: ${body.length}');
  } catch (e) {
    print('  ERROR: $e');
  } finally {
    client5.close();
  }

  // Attempt 6: Try Google's cached version via Startpage
  print('\n=== Attempt 6: Bing cache for Intel specs ===');
  try {
    final resp = await http.get(
      Uri.parse('https://cc.bingj.com/cache.aspx?q=Core+i9-14900K+specifications+site%3aintel.com&d=4503599627370497&mkt=en-US&setlang=en-US&w=wL4lFPSnx4MaFRbYwf0mTcXoNyxiKTmE'),
      headers: {'User-Agent': ua},
    ).timeout(const Duration(seconds: 15));
    print('  Bing cache status: ${resp.statusCode}');
    print('  Body length: ${resp.body.length}');
  } catch (e) {
    print('  ERROR: $e');
  }
}
