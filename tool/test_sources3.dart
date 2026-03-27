import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  // Test 1: Notebookcheck Laptop_Search table structure
  print('=== Notebookcheck Laptop_Search table rows ===');
  try {
    final url = Uri.parse(
      'https://www.notebookcheck.net/Laptop_Search.8223.0.html'
      '?model=${Uri.encodeComponent("ThinkPad X1 Carbon")}',
    );
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(const Duration(seconds: 15));
    final html = utf8.decode(r.bodyBytes, allowMalformed: true);

    // Get first few table rows
    final trs = RegExp(
      r'<tr[^>]*class="[^"]*(?:odd|even)[^"]*"[^>]*>(.*?)</tr>',
      dotAll: true,
    ).allMatches(html);
    print('Total rows: ${trs.length}');
    int count = 0;
    for (final tr in trs) {
      if (count >= 3) break;
      count++;
      final row = tr.group(1)!;
      print('\n--- Row $count ---');
      // Show first 800 chars of the row
      print(row.substring(0, row.length.clamp(0, 800)));
    }

    // Also check: what's the table header?
    final thead = RegExp(
      r'<tr[^>]*class="[^"]*head[^"]*"[^>]*>(.*?)</tr>',
      dotAll: true,
    ).firstMatch(html);
    if (thead != null) {
      print('\n--- Table Header ---');
      final h = thead.group(1)!;
      final ths = RegExp(r'<th[^>]*>(.*?)</th>', dotAll: true).allMatches(h);
      for (final th in ths) {
        final text = th.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        print('  TH: $text');
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 2: DuckDuckGo Lite with correct parsing
  print('\n\n=== DuckDuckGo Lite ===');
  try {
    final url = Uri.parse('https://lite.duckduckgo.com/lite/');
    final r = await http.post(url, headers: {
      'User-Agent': ua,
      'Content-Type': 'application/x-www-form-urlencoded',
    }, body: 'q=${Uri.encodeComponent("ThinkPad X1 Carbon Gen 12 specifications")}',
    ).timeout(const Duration(seconds: 15));
    print('Status: ${r.statusCode}');
    final html = utf8.decode(r.bodyBytes, allowMalformed: true);

    // DDG Lite uses single-quoted class: class='result-link'
    final links = RegExp(
      r'''<a\s+rel="nofollow"\s+href="(https?://[^"]+)"\s+class='result-link'>\s*(.*?)\s*</a>''',
      dotAll: true,
    ).allMatches(html);
    print('Result links: ${links.length}');
    for (final l in links.take(10)) {
      final title = l.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      final href = l.group(1)!;
      print('  $title');
      print('    -> $href');
    }

    // Also get the snippet for each result
    final snippets = RegExp(
      r'''class='result-snippet'[^>]*>\s*(.*?)\s*</(?:td|span|div)>''',
      dotAll: true,
    ).allMatches(html);
    print('\nSnippets: ${snippets.length}');
    for (final s in snippets.take(5)) {
      final text = s.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      print('  ${text.substring(0, text.length.clamp(0, 150))}');
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 3: DuckDuckGo Lite for phone specs
  print('\n\n=== DDG Lite phone ===');
  try {
    final url = Uri.parse('https://lite.duckduckgo.com/lite/');
    final r = await http.post(url, headers: {
      'User-Agent': ua,
      'Content-Type': 'application/x-www-form-urlencoded',
    }, body: 'q=${Uri.encodeComponent("Samsung Galaxy S24 Ultra specifications gsmarena")}',
    ).timeout(const Duration(seconds: 15));
    final html = utf8.decode(r.bodyBytes, allowMalformed: true);
    final links = RegExp(
      r'''<a\s+rel="nofollow"\s+href="(https?://[^"]+)"\s+class='result-link'>\s*(.*?)\s*</a>''',
      dotAll: true,
    ).allMatches(html);
    print('Result links: ${links.length}');
    for (final l in links.take(5)) {
      final title = l.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      print('  $title -> ${l.group(1)}');
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 4: Notebookcheck AJAX content format
  print('\n\n=== Notebookcheck AJAX content ===');
  try {
    final url = Uri.parse(
      'https://www.notebookcheck.net/Laptop_Search.8223.0.html'
      '?ajaxsearch=${Uri.encodeComponent("ThinkPad X1 Carbon")}',
    );
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': '*/*',
      'X-Requested-With': 'XMLHttpRequest',
    }).timeout(const Duration(seconds: 15));
    final body = utf8.decode(r.bodyBytes, allowMalformed: true);
    print('Body: ${r.bodyBytes.length} bytes');
    // Check if it's JSON
    if (body.trimLeft().startsWith('{') || body.trimLeft().startsWith('[')) {
      print('Format: JSON');
      print(body.substring(0, body.length.clamp(0, 2000)));
    } else if (body.contains('<')) {
      print('Format: HTML');
      // Look for table rows
      final trs = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true).allMatches(body);
      print('Table rows: ${trs.length}');
      // Show first row
      if (trs.isNotEmpty) {
        final firstRow = trs.first.group(0)!;
        print('First row: ${firstRow.substring(0, firstRow.length.clamp(0, 500))}');
      }
      // Look for links
      final links = RegExp(r'href="([^"]*\.html)"').allMatches(body);
      print('Links: ${links.length}');
      for (final l in links.take(5)) {
        print('  ${l.group(1)}');
      }
      // Show first 2000 chars
      print('First 2000:\n${body.substring(0, body.length.clamp(0, 2000))}');
    } else {
      print('Format: unknown');
      print(body.substring(0, body.length.clamp(0, 1000)));
    }
  } catch (e) {
    print('Error: $e');
  }
}
