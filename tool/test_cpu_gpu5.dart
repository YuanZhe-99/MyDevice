// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

String _strip(String html) => html.replaceAll(RegExp(r'<[^>]+>'), '').trim();

Future<void> main() async {
  // ── TechPowerUp autocomplete / search API ──
  print('=== TechPowerUp autocomplete variations ===');
  final tpuEndpoints = [
    'https://www.techpowerup.com/cpu-specs/ajax.php?s=ryzen+9+7950x',
    'https://www.techpowerup.com/cpu-specs/search?q=ryzen+9+7950x',
    'https://www.techpowerup.com/ajax/cpuspecsearch?q=ryzen+9+7950x',
    'https://www.techpowerup.com/api/search?q=ryzen+9+7950x&type=cpu',
  ];
  for (final url in tpuEndpoints) {
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _ua, 'Accept': 'application/json,text/html'},
      ).timeout(const Duration(seconds: 8));
      print('  $url');
      print('    status: ${resp.statusCode}  size: ${resp.body.length}');
      if (resp.statusCode == 200 && resp.body.length < 2000) {
        print('    body: ${resp.body.substring(0, resp.body.length.clamp(0, 500))}');
      }
    } catch (e) {
      print('  $url → ERROR: $e');
    }
  }

  // ── TechPowerUp: try URL without ID ──
  print('\n=== TechPowerUp: URL without .c ID ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.techpowerup.com/cpu-specs/ryzen-9-7950x'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}');
    if (resp.statusCode == 301 || resp.statusCode == 302) {
      print('  redirect: ${resp.headers['location']}');
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── PassMark CPU ──
  print('\n=== PassMark CPU Lookup ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.cpubenchmark.net/cpu_lookup.php?cpu=AMD+Ryzen+9+7950X&id=0'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
    if (resp.statusCode == 200 && resp.body.length < 1000) {
      print('  body: ${resp.body}');
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── PassMark CPU search ──
  print('\n=== PassMark CPU Search API ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.cpubenchmark.net/cpu_list.php'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Nano: try direct CPU page ──
  print('\n=== NanoReview CPU ===');
  try {
    final resp = await http.get(
      Uri.parse('https://nanoreview.net/en/cpu/amd-ryzen-9-7950x'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
    if (resp.statusCode == 200) {
      // Check for specs
      final specs = RegExp(r'<td[^>]*class="[^"]*spec-name[^"]*"[^>]*>([^<]+)</td>\s*<td[^>]*>([^<]+)</td>', dotAll: true)
          .allMatches(resp.body).take(10);
      for (final m in specs) {
        print('    ${_strip(m.group(1)!)}: ${_strip(m.group(2)!)}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Try ProductSpecs.net ──
  print('\n=== ProductSpecs.net ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.productspecs.net/search?q=Intel+Core+Ultra+7+258V'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── WikiData SPARQL for CPU ──
  print('\n=== Wikidata SPARQL: CPU ===');
  try {
    final sparql = '''
SELECT ?item ?itemLabel ?cores ?threads ?freq ?arch ?archLabel WHERE {
  ?item wdt:P31 wd:Q610398.
  ?item rdfs:label ?itemLabel.
  FILTER(LANG(?itemLabel) = "en")
  FILTER(CONTAINS(LCASE(?itemLabel), "ryzen 9 7950x"))
  OPTIONAL { ?item wdt:P1141 ?cores. }
  OPTIONAL { ?item wdt:P5765 ?threads. }
  OPTIONAL { ?item wdt:P2144 ?freq. }
  OPTIONAL { ?item wdt:P277 ?arch. ?arch rdfs:label ?archLabel. FILTER(LANG(?archLabel) = "en") }
}
LIMIT 5
''';
    final resp = await http.get(
      Uri.parse('https://query.wikidata.org/sparql?query=${Uri.encodeComponent(sparql)}&format=json'),
      headers: {'User-Agent': '$_ua (MyDevice App)', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    print('  status: ${resp.statusCode}');
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final results = data['results']['bindings'] as List;
      print('  results: ${results.length}');
      for (final r in results) {
        print('    ${r['itemLabel']?['value']}: cores=${r['cores']?['value']} threads=${r['threads']?['value']} freq=${r['freq']?['value']} arch=${r['archLabel']?['value']}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Try different Wikidata class (central processing unit model) ──
  print('\n=== Wikidata SPARQL: CPU model v2 ===');
  try {
    final sparql = '''
SELECT ?item ?itemLabel ?cores ?threads WHERE {
  ?item rdfs:label ?itemLabel.
  FILTER(LANG(?itemLabel) = "en")
  FILTER(CONTAINS(LCASE(?itemLabel), "ryzen 9 7950x"))
  OPTIONAL { ?item wdt:P1141 ?cores. }
  OPTIONAL { ?item wdt:P5765 ?threads. }
}
LIMIT 5
''';
    final resp = await http.get(
      Uri.parse('https://query.wikidata.org/sparql?query=${Uri.encodeComponent(sparql)}&format=json'),
      headers: {'User-Agent': '$_ua (MyDevice App)', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    print('  status: ${resp.statusCode}');
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final results = data['results']['bindings'] as List;
      print('  results: ${results.length}');
      for (final r in results) {
        print('    ${r['itemLabel']?['value']}: cores=${r['cores']?['value']} threads=${r['threads']?['value']}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }
}
