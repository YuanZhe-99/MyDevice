import 'dart:convert';
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  // Test 1: Analyze TechPowerUp CPU main page structure
  print('=== TechPowerUp CPU Main Page Analysis ===');
  try {
    final resp = await http
        .get(Uri.parse('https://www.techpowerup.com/cpu-specs/'),
            headers: {'User-Agent': ua, 'Accept': 'text/html'})
        .timeout(const Duration(seconds: 15));
    print('Status: ${resp.statusCode}');
    print('Body length: ${resp.body.length}');

    // Check for table elements
    final tables = RegExp(r'<table[^>]*>').allMatches(resp.body);
    print('Tables: ${tables.length}');

    // Check for tr elements with CPU data
    final rows = RegExp(r'<tr[^>]*>').allMatches(resp.body);
    print('Table rows: ${rows.length}');

    // Check for /cpu-specs/ links in the page
    final cpuLinks = RegExp(
      r'href="(/cpu-specs/[^"]+\.c\d+)"',
    ).allMatches(resp.body);
    print('CPU detail links: ${cpuLinks.length}');
    for (final m in cpuLinks.take(5)) {
      print('  ${m.group(1)}');
    }

    // Look for JavaScript data stores / JSON
    final jsonBlocks = RegExp(r'var\s+(\w+)\s*=\s*\[').allMatches(resp.body);
    print('JS array variables: ${jsonBlocks.length}');
    for (final m in jsonBlocks.take(5)) {
      print('  ${m.group(0)}');
    }

    // Look for __NEXT_DATA__ or similar
    if (resp.body.contains('__NEXT_DATA__')) print('Has __NEXT_DATA__');
    if (resp.body.contains('__NUXT')) print('Has __NUXT');

    // Look for fetch/XHR calls in scripts
    final scriptBlocks = RegExp(r'<script[^>]*>(.*?)</script>', dotAll: true)
        .allMatches(resp.body);
    print('Script blocks: ${scriptBlocks.length}');
    for (final s in scriptBlocks) {
      final content = s.group(1)!;
      if (content.contains('cpu-specs') || content.contains('cpuSpecs') ||
          content.contains('triggerSearch') || content.contains('urlObj')) {
        print('  Relevant script (${content.length} chars):');
        // Find fetch/XMLHttpRequest calls
        final fetches = RegExp(r'fetch\([^)]+\)|\.ajax\([^)]+\)|url[^;]{0,200}')
            .allMatches(content);
        for (final f in fetches.take(5)) {
          print('    ${f.group(0)!.substring(0, f.group(0)!.length.clamp(0, 150))}');
        }
        // Find triggerSearch function
        final searchFn = RegExp(r'triggerSearch[^}]+\}').firstMatch(content);
        if (searchFn != null) {
          print('    triggerSearch: ${searchFn.group(0)!.substring(0, searchFn.group(0)!.length.clamp(0, 300))}');
        }
        // Show first 500 chars if short
        if (content.length < 2000) {
          print('    Full: ${content.substring(0, content.length.clamp(0, 500))}');
        }
      }
    }

    // Check for noscript
    if (resp.body.contains('<noscript>')) {
      final ns = RegExp(r'<noscript>(.*?)</noscript>', dotAll: true)
          .firstMatch(resp.body);
      if (ns != null) {
        print('Noscript content (first 200): ${ns.group(1)!.substring(0, ns.group(1)!.length.clamp(0, 200))}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 2: Try TechPowerUp with different URL formats
  print('\n\n=== TechPowerUp URL patterns ===');
  final patterns = [
    'https://www.techpowerup.com/cpu-specs/?q=Core+i5+520M',
    'https://www.techpowerup.com/cpu-specs/?search=Core+i5+520M',
    'https://www.techpowerup.com/cpu-specs/?s=Core+i5+520M',
    'https://www.techpowerup.com/cpu-specs/core-i5-520m.c1',
    'https://www.techpowerup.com/cpu-specs/core-i5-520m',
  ];
  for (final url in patterns) {
    try {
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': ua})
          .timeout(const Duration(seconds: 10));
      print('$url → ${resp.statusCode} (${resp.body.length} bytes)');
      if (resp.statusCode == 200 && resp.body.length > 1000) {
        final title = RegExp(r'<title>([^<]+)').firstMatch(resp.body);
        if (title != null) print('  Title: ${title.group(1)}');
      }
    } catch (e) {
      print('$url → Error: $e');
    }
  }

  // Test 3: Bing search with deeper parsing
  print('\n\n=== Bing Search (deeper parsing) ===');
  try {
    final q = Uri.encodeComponent('Intel Core i5-520M specs');
    final url = 'https://www.bing.com/search?q=$q';
    final resp = await http
        .get(Uri.parse(url), headers: {
          'User-Agent': ua,
          'Accept-Language': 'en-US,en;q=0.9',
        })
        .timeout(const Duration(seconds: 15));
    print('Status: ${resp.statusCode}');
    // Extract all result URLs
    final allLinks = RegExp(r'<a[^>]*href="(https?://[^"]+)"[^>]*>')
        .allMatches(resp.body);
    print('All links: ${allLinks.length}');
    // Filter for relevant domains
    for (final m in allLinks) {
      final href = m.group(1)!;
      if (href.contains('techpowerup') ||
          href.contains('ark.intel') ||
          href.contains('cpu-benchmark') ||
          href.contains('cpu-world') ||
          href.contains('cpubenchmark') ||
          href.contains('notebookcheck')) {
        print('  $href');
      }
    }
    // Also look for cite elements (Bing result URLs)
    final cites = RegExp(r'<cite[^>]*>([^<]+)</cite>')
        .allMatches(resp.body);
    print('Cite elements:');
    for (final c in cites.take(10)) {
      print('  ${c.group(1)}');
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 4: Try search with Startpage (privacy search engine)
  print('\n\n=== Startpage Search ===');
  try {
    final resp = await http.post(
      Uri.parse('https://www.startpage.com/sp/search'),
      headers: {
        'User-Agent': ua,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'query=${Uri.encodeComponent("Core i5-520M site:techpowerup.com/cpu-specs")}',
    ).timeout(const Duration(seconds: 15));
    print('Status: ${resp.statusCode}');
    print('Body length: ${resp.body.length}');
    final tpuLinks = RegExp(
      r'(https?://www\.techpowerup\.com/cpu-specs/[^\s"&<]+)',
    ).allMatches(resp.body);
    print('TechPowerUp links: ${tpuLinks.length}');
    for (final m in tpuLinks.take(5)) {
      print('  ${m.group(1)}');
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 5: SearXNG public instance
  print('\n\n=== SearXNG Search ===');
  try {
    // Try a public SearXNG instance
    final q = Uri.encodeComponent('Core i5-520M site:techpowerup.com/cpu-specs');
    final url = 'https://searx.be/search?q=$q&format=json';
    final resp = await http
        .get(Uri.parse(url), headers: {
          'User-Agent': ua,
          'Accept': 'application/json',
        })
        .timeout(const Duration(seconds: 15));
    print('Status: ${resp.statusCode}');
    print('Body length: ${resp.body.length}');
    if (resp.statusCode == 200) {
      try {
        final json = jsonDecode(resp.body);
        if (json is Map && json['results'] is List) {
          final results = json['results'] as List;
          print('Results: ${results.length}');
          for (final r in results.take(5)) {
            print('  ${r['title']} → ${r['url']}');
          }
        }
      } catch (_) {
        print('Not valid JSON');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
