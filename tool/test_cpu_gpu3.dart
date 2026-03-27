// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

String _strip(String html) => html.replaceAll(RegExp(r'<[^>]+>'), '').trim();

Future<void> main() async {
  // ── TechPowerUp GPU page raw HTML structure ──
  print('=== TechPowerUp GPU Detail: RAW HTML ANALYSIS ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.techpowerup.com/gpu-specs/geforce-rtx-4090.c3889'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final html = resp.body;
      // Print all unique tag patterns
      final allTags = RegExp(r'<(\w+)[^>]*class="([^"]+)"')
          .allMatches(html)
          .map((m) => '${m.group(1)}.${m.group(2)}')
          .toSet()
          .toList()
        ..sort();
      print('  Unique class elements: ${allTags.length}');
      for (final t in allTags.take(40)) {
        print('    $t');
      }
      
      // Look for "Architecture" text
      final archIdx = html.indexOf('Architecture');
      if (archIdx >= 0) {
        print('\n  Context around "Architecture":');
        final start = (archIdx - 200).clamp(0, html.length);
        final end = (archIdx + 200).clamp(0, html.length);
        print('    ${html.substring(start, end)}');
      }
      
      // Look for "GPU Name" text
      final gpuIdx = html.indexOf('GPU Name');
      if (gpuIdx >= 0) {
        print('\n  Context around "GPU Name":');
        final start = (gpuIdx - 200).clamp(0, html.length);
        final end = (gpuIdx + 200).clamp(0, html.length);
        print('    ${html.substring(start, end)}');
      }

      // Check if content is in noscript or similar
      if (html.contains('<noscript>')) {
        print('\n  Has <noscript> tags');
      }
      if (html.contains('__NEXT_DATA__')) {
        print('  Has __NEXT_DATA__ (Next.js)');
      }
      if (html.contains('__NUXT__')) {
        print('  Has __NUXT__ (Nuxt.js)');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── TechPowerUp GPU specs list page structure ──
  print('\n=== TechPowerUp GPU Specs List: RAW HTML ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.techpowerup.com/gpu-specs/'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final html = resp.body;
      // Look for table or list structure
      final tables = RegExp(r'<table[^>]*>').allMatches(html).length;
      print('  Number of tables: $tables');
      
      // Look for gpu-specs links
      final gpuLinks = RegExp(r'href="(/gpu-specs/[^"]+)"')
          .allMatches(html).take(10);
      for (final l in gpuLinks) {
        print('  Link: ${l.group(1)}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Try Intel ARK via different approach ──
  print('\n=== Intel product spec auto-complete ===');
  try {
    // Intel has a different API endpoint
    final resp = await http.get(
      Uri.parse(
          'https://platform.cloud.coveo.com/rest/search/v2?q=Core+Ultra+7+258V'
          '&maximumAge=900000&locale=en'
          '&pipeline=QSSIntelProducts_EN_US&searchHub=QSSIntelProductSearch_EN_US'
      ),
      headers: {
        'User-Agent': _ua,
        'Accept': 'application/json',
        'Authorization': 'Bearer xx885c7d71-2d8a-40a6-91df-c42b0e437651',
      },
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      print('  first 500: ${resp.body.substring(0, 500.clamp(0, resp.body.length))}');
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Try Wikichip ──
  print('\n=== WikiChip ===');
  try {
    final resp = await http.get(
      Uri.parse('https://en.wikichip.org/w/index.php?search=Core+Ultra+7+258V'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final html = resp.body;
      final links = RegExp(r'<a[^>]*href="(/wiki/[^"]+)"[^>]*>([^<]+)</a>')
          .allMatches(html)
          .where((m) => m.group(2)!.toLowerCase().contains('core'))
          .take(5);
      for (final l in links) {
        print('    ${l.group(2)} -> ${l.group(1)}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Try WikiChip detail page ──
  print('\n=== WikiChip Detail: Ryzen 9 7950X ===');
  try {
    final resp = await http.get(
      Uri.parse('https://en.wikichip.org/wiki/amd/ryzen_9/7950x'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final html = resp.body;
      // Look for spec infobox
      final thTd = RegExp(r'<t[hd][^>]*>([^<]*(?:<[^>]+>[^<]*)*?)</t[hd]>\s*<t[hd][^>]*>([^<]*(?:<[^>]+>[^<]*)*?)</t[hd]>', dotAll: true)
          .allMatches(html);
      int count = 0;
      for (final m in thTd) {
        final key = _strip(m.group(1)!);
        final value = _strip(m.group(2)!);
        if (key.isNotEmpty && value.isNotEmpty && key.length < 30) {
          print('    $key: $value');
          count++;
          if (count >= 20) break;
        }
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Geekbench ──
  print('\n=== Geekbench Processor Search ===');
  try {
    final resp = await http.get(
      Uri.parse('https://browser.geekbench.com/processor-benchmarks'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── DuckDuckGo for CPU specs ──
  print('\n=== DuckDuckGo Lite: CPU search ===');
  try {
    final resp = await http.post(
      Uri.parse('https://lite.duckduckgo.com/lite/'),
      headers: {'User-Agent': _ua, 'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'q=${Uri.encodeComponent("Intel Core Ultra 7 258V specifications")}&kl=us-en',
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final links = RegExp(r"class='result-link'[^>]*>([^<]+)</a>")
          .allMatches(resp.body)
          .take(5);
      for (final l in links) {
        print('    ${l.group(1)}');
      }
      // Also get URLs
      final urls = RegExp(r"class='result-link'[^>]*href='([^']+)'")
          .allMatches(resp.body)
          .take(5);
      for (final u in urls) {
        print('    URL: ${u.group(1)}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }
}
