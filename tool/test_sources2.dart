import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  // Test 1: Notebookcheck Laptop_Search
  print('=== Notebookcheck Laptop_Search ===');
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
    print('Status: ${r.statusCode}');
    print('Body: ${r.bodyBytes.length} bytes');
    if (r.statusCode == 200) {
      final html = utf8.decode(r.bodyBytes, allowMalformed: true);
      final links = RegExp(
        r'<a[^>]*href="(/[^"]*\.html)"[^>]*>\s*([^<]{5,}?)\s*</a>',
      ).allMatches(html);
      print('Links with title: ${links.length}');
      final seen = <String>{};
      for (final l in links) {
        final title = l.group(2)!.trim();
        if (title.length > 10 && seen.add(l.group(1)!) && seen.length <= 15) {
          print('  $title -> ${l.group(1)}');
        }
      }
      final trs = RegExp(r'<tr[^>]*class="[^"]*(?:odd|even)[^"]*"', dotAll: true).allMatches(html);
      print('Table rows with odd/even class: ${trs.length}');
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 2: Notebookcheck Laptop_Search POST
  print('\n=== Notebookcheck Laptop_Search POST ===');
  try {
    final url = Uri.parse(
      'https://www.notebookcheck.net/Laptop_Search.8223.0.html',
    );
    final r = await http.post(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
      'Content-Type': 'application/x-www-form-urlencoded',
    }, body: 'model=${Uri.encodeComponent("ThinkPad X1 Carbon")}',
    ).timeout(const Duration(seconds: 15));
    print('Status: ${r.statusCode}');
    print('Body: ${r.bodyBytes.length} bytes');
    if (r.statusCode == 200) {
      final html = utf8.decode(r.bodyBytes, allowMalformed: true);
      final links = RegExp(
        r'<a[^>]*href="(/[^"]*\.html)"[^>]*>\s*([^<]{5,}?)\s*</a>',
      ).allMatches(html);
      print('Links: ${links.length}');
      final seen = <String>{};
      for (final l in links) {
        final title = l.group(2)!.trim();
        if (title.length > 10 && seen.add(l.group(1)!) && seen.length <= 15) {
          print('  $title -> ${l.group(1)}');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 3: Notebookcheck AJAX
  print('\n=== Notebookcheck AJAX ===');
  for (final ep in [
    'https://www.notebookcheck.net/Laptop_Search.8223.0.html?ajaxsearch=${Uri.encodeComponent("ThinkPad")}',
    'https://www.notebookcheck.net/Laptop_Search.8223.0.html?ajaxsearch=ThinkPad&model=ThinkPad',
  ]) {
    try {
      final r = await http.get(Uri.parse(ep), headers: {
        'User-Agent': ua,
        'Accept': '*/*',
        'X-Requested-With': 'XMLHttpRequest',
      }).timeout(const Duration(seconds: 10));
      print('  Status: ${r.statusCode}, Body: ${r.bodyBytes.length}');
      if (r.statusCode == 200 && r.bodyBytes.length < 5000) {
        final body = utf8.decode(r.bodyBytes, allowMalformed: true);
        print('  Response: ${body.substring(0, body.length.clamp(0, 500))}');
      }
    } catch (e) {
      print('  Error: $e');
    }
  }

  // Test 4: gsmarena autocomplete
  print('\n=== GSMArena autocomplete ===');
  try {
    final url = Uri.parse(
      'https://www.gsmarena.com/quicksearch.php3?sSearch=${Uri.encodeComponent("iPhone 15")}',
    );
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': '*/*',
      'X-Requested-With': 'XMLHttpRequest',
    }).timeout(const Duration(seconds: 10));
    print('Status: ${r.statusCode}, Body: ${r.bodyBytes.length}');
    if (r.bodyBytes.length < 3000 && r.bodyBytes.isNotEmpty) {
      final body = utf8.decode(r.bodyBytes, allowMalformed: true);
      print('Content: ${body.substring(0, body.length.clamp(0, 1000))}');
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 5: Wikidata SPARQL
  print('\n=== Wikidata SPARQL ===');
  try {
    final sparql = r'''
SELECT ?item ?itemLabel ?brand ?brandLabel WHERE {
  ?item wdt:P31/wdt:P279* wd:Q22645.
  ?item rdfs:label ?label.
  FILTER(CONTAINS(LCASE(?label), "iphone 15 pro"))
  FILTER(LANG(?label) = "en")
  OPTIONAL { ?item wdt:P176 ?brand }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
LIMIT 5
''';
    final url = Uri.parse(
      'https://query.wikidata.org/sparql?format=json'
      '&query=${Uri.encodeComponent(sparql)}',
    );
    final r = await http.get(url, headers: {
      'User-Agent': 'MyDevice/0.5 (Flutter app; device-inventory)',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 15));
    print('Status: ${r.statusCode}');
    if (r.statusCode == 200) {
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      final results = (json['results'] as Map<String, dynamic>)['bindings'] as List;
      print('Results: ${results.length}');
      for (final item in results.take(5)) {
        final m = item as Map<String, dynamic>;
        print('  ${m['itemLabel']?['value']} (${m['item']?['value']})');
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 6: DuckDuckGo Lite
  print('\n=== DuckDuckGo Lite ===');
  try {
    final url = Uri.parse('https://lite.duckduckgo.com/lite/');
    final r = await http.post(url, headers: {
      'User-Agent': ua,
      'Content-Type': 'application/x-www-form-urlencoded',
    }, body: 'q=${Uri.encodeComponent("iPhone 15 Pro gsmarena specifications")}',
    ).timeout(const Duration(seconds: 15));
    print('Status: ${r.statusCode}, Body: ${r.bodyBytes.length}');
    if (r.statusCode == 200) {
      final html = utf8.decode(r.bodyBytes, allowMalformed: true);
      // DDG Lite uses simple HTML - look for result links
      final links = RegExp(
        r'<a[^>]*rel="nofollow"[^>]*href="(https?://[^"]+)"[^>]*class="result-link"[^>]*>\s*(.*?)\s*</a>',
        dotAll: true,
      ).allMatches(html);
      print('Result links (nofollow): ${links.length}');
      // Try simpler pattern
      final simpleLinks = RegExp(
        r'class="result-link"[^>]*>\s*(.*?)\s*</a>',
        dotAll: true,
      ).allMatches(html);
      print('Result links (class): ${simpleLinks.length}');
      // Just look for any link with "result" in class
      final anyRes = RegExp(r'class="[^"]*result[^"]*"').allMatches(html);
      print('Any result class: ${anyRes.length}');
      // Show snippet of the HTML around "result"
      final idx = html.indexOf('result');
      if (idx > 0) {
        final start = (idx - 200).clamp(0, html.length);
        final end = (idx + 500).clamp(0, html.length);
        print('Context around "result":\n${html.substring(start, end)}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
