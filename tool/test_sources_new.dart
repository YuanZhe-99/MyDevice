import 'dart:convert';
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  // Test 1: TechPowerUp CPU specs with search parameter
  print('=== TechPowerUp CPU Specs Search ===');
  for (final q in [
    'Core i5 520M',
    'Ryzen 9 7950X',
    'Snapdragon 8 Gen 3',
    'Apple M3 Max',
  ]) {
    try {
      final url =
          'https://www.techpowerup.com/cpu-specs/?ajaxsrch=$q';
      print('\nSearching: $q');
      print('URL: $url');
      final resp = await http
          .get(Uri.parse(url), headers: {
            'User-Agent': ua,
            'Accept': 'text/html',
          })
          .timeout(const Duration(seconds: 15));
      print('Status: ${resp.statusCode}');
      print('Body length: ${resp.body.length}');
      // Look for CPU links
      final links = RegExp(
        r'<a href="(/cpu-specs/[^"]+)"[^>]*>([^<]+)</a>',
      ).allMatches(resp.body);
      print('Found ${links.length} CPU links');
      for (final m in links.take(5)) {
        print('  ${m.group(2)} → ${m.group(1)}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Test 2: TechPowerUp GPU specs with search parameter
  print('\n\n=== TechPowerUp GPU Specs Search ===');
  for (final q in [
    'RTX 4090',
    'Adreno X1-85',
    'Apple M3 Max GPU',
  ]) {
    try {
      final url =
          'https://www.techpowerup.com/gpu-specs/?ajaxsrch=$q';
      print('\nSearching: $q');
      final resp = await http
          .get(Uri.parse(url), headers: {
            'User-Agent': ua,
            'Accept': 'text/html',
          })
          .timeout(const Duration(seconds: 15));
      print('Status: ${resp.statusCode}');
      print('Body length: ${resp.body.length}');
      final links = RegExp(
        r'<a href="(/gpu-specs/[^"]+)"[^>]*>([^<]+)</a>',
      ).allMatches(resp.body);
      print('Found ${links.length} GPU links');
      for (final m in links.take(5)) {
        print('  ${m.group(2)} → ${m.group(1)}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Test 3: TechPowerUp CPU specs main page (for search form analysis)
  print('\n\n=== TechPowerUp CPU Specs Main Page ===');
  try {
    final resp = await http
        .get(Uri.parse('https://www.techpowerup.com/cpu-specs/'),
            headers: {'User-Agent': ua, 'Accept': 'text/html'})
        .timeout(const Duration(seconds: 15));
    print('Status: ${resp.statusCode}');
    print('Body length: ${resp.body.length}');
    // Look for form/search elements
    final forms = RegExp(r'<form[^>]*>').allMatches(resp.body);
    print('Forms found: ${forms.length}');
    for (final f in forms) {
      print('  ${f.group(0)}');
    }
    // Look for input fields
    final inputs = RegExp(r'<input[^>]*name="([^"]*)"[^>]*>')
        .allMatches(resp.body);
    print('Input fields:');
    for (final i in inputs) {
      print('  ${i.group(0)?.substring(0, i.group(0)!.length.clamp(0, 100))}');
    }
    // Check for ajax/API endpoints in JS
    final ajaxUrls = RegExp(r"""(ajax|api|search|fetch)[^"']*""",
            caseSensitive: false)
        .allMatches(resp.body);
    print('Ajax/API references (first 10):');
    var count = 0;
    for (final a in ajaxUrls) {
      if (count++ >= 10) break;
      final s = a.group(0)!;
      if (s.length < 200) print('  $s');
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 4: TechPowerUp search with mobile queries (different URL patterns)
  print('\n\n=== TechPowerUp CPU Specs Filter ===');
  try {
    // Try filter approach: mfgr=Intel&model=Core+i5
    final url = 'https://www.techpowerup.com/cpu-specs/?mfgr=Intel&sort=name&ajax=1';
    print('URL: $url');
    final resp = await http
        .get(Uri.parse(url), headers: {
          'User-Agent': ua,
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest',
        })
        .timeout(const Duration(seconds: 15));
    print('Status: ${resp.statusCode}');
    print('Body length: ${resp.body.length}');
    final links = RegExp(
      r'<a href="(/cpu-specs/[^"]+)"[^>]*>([^<]+)</a>',
    ).allMatches(resp.body);
    print('Found ${links.length} CPU links');
    for (final m in links.take(5)) {
      print('  ${m.group(2)} → ${m.group(1)}');
    }
    // Show a snippet
    if (resp.body.length > 100) {
      print('First 500 chars: ${resp.body.substring(0, resp.body.length.clamp(0, 500))}');
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 5: Bing search for TechPowerUp CPU pages
  print('\n\n=== Bing Search → TechPowerUp ===');
  try {
    final q = Uri.encodeComponent('Core i5 520M site:techpowerup.com/cpu-specs');
    final url = 'https://www.bing.com/search?q=$q&count=5';
    print('URL: $url');
    final resp = await http
        .get(Uri.parse(url), headers: {
          'User-Agent': ua,
          'Accept': 'text/html',
        })
        .timeout(const Duration(seconds: 15));
    print('Status: ${resp.statusCode}');
    print('Body length: ${resp.body.length}');
    // Extract TechPowerUp URLs from Bing results
    final tpuLinks = RegExp(
      r'href="(https?://www\.techpowerup\.com/cpu-specs/[^"]+)"',
    ).allMatches(resp.body);
    print('TechPowerUp links: ${tpuLinks.length}');
    for (final m in tpuLinks.take(5)) {
      print('  ${m.group(1)}');
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 6: Google search for TechPowerUp CPU pages
  print('\n\n=== Google Search → TechPowerUp ===');
  try {
    final q = Uri.encodeComponent('Core i5 520M site:techpowerup.com/cpu-specs');
    final url = 'https://www.google.com/search?q=$q&num=5';
    print('URL: $url');
    final resp = await http
        .get(Uri.parse(url), headers: {
          'User-Agent': ua,
          'Accept': 'text/html',
        })
        .timeout(const Duration(seconds: 15));
    print('Status: ${resp.statusCode}');
    print('Body length: ${resp.body.length}');
    final tpuLinks = RegExp(
      r'(https?://www\.techpowerup\.com/cpu-specs/[^\s"&]+)',
    ).allMatches(resp.body);
    print('TechPowerUp links: ${tpuLinks.length}');
    for (final m in tpuLinks.take(5)) {
      print('  ${m.group(1)}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
