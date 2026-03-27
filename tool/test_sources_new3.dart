import 'dart:convert';
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  // Test 1: Startpage for various CPUs
  print('=== Startpage → TechPowerUp CPU ===');
  for (final q in [
    'Core i5 520M',
    'Ryzen 9 7950X',
    'Snapdragon 8 Gen 3',
    'Apple M3 Max',
    'Core Ultra 7 258V',
  ]) {
    print('\nQuery: $q');
    try {
      final resp = await http.post(
        Uri.parse('https://www.startpage.com/sp/search'),
        headers: {
          'User-Agent': ua,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'query=${Uri.encodeComponent("$q site:techpowerup.com/cpu-specs")}',
      ).timeout(const Duration(seconds: 15));
      print('  Status: ${resp.statusCode}');
      print('  Body: ${resp.body.length} bytes');
      final tpuLinks = RegExp(
        r'(https?://www\.techpowerup\.com/cpu-specs/[^\s"&<]+\.c\d+)',
      ).allMatches(resp.body).map((m) => m.group(1)!).toSet();
      print('  Unique TechPowerUp CPU links: ${tpuLinks.length}');
      for (final l in tpuLinks.take(3)) {
        print('    $l');
      }
    } catch (e) {
      print('  Error: $e');
    }
    // Small delay to avoid rate limiting
    await Future.delayed(const Duration(seconds: 2));
  }

  // Test 2: Startpage for GPU
  print('\n\n=== Startpage → TechPowerUp GPU ===');
  for (final q in [
    'RTX 4090',
    'Adreno X1-85',
    'Radeon RX 7900 XTX',
  ]) {
    print('\nQuery: $q');
    try {
      final resp = await http.post(
        Uri.parse('https://www.startpage.com/sp/search'),
        headers: {
          'User-Agent': ua,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'query=${Uri.encodeComponent("$q site:techpowerup.com/gpu-specs")}',
      ).timeout(const Duration(seconds: 15));
      print('  Status: ${resp.statusCode}');
      print('  Body: ${resp.body.length} bytes');
      final tpuLinks = RegExp(
        r'(https?://www\.techpowerup\.com/gpu-specs/[^\s"&<]+\.c\d+)',
      ).allMatches(resp.body).map((m) => m.group(1)!).toSet();
      print('  Unique TechPowerUp GPU links: ${tpuLinks.length}');
      for (final l in tpuLinks.take(3)) {
        print('    $l');
      }
    } catch (e) {
      print('  Error: $e');
    }
    await Future.delayed(const Duration(seconds: 2));
  }

  // Test 3: Now fetch the actual TechPowerUp CPU page for Core i5-520M
  print('\n\n=== TechPowerUp CPU Detail: Core i5-520M ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.techpowerup.com/cpu-specs/core-i5-520m.c4365'),
      headers: {'User-Agent': ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));
    print('Status: ${resp.statusCode}');
    print('Body: ${resp.body.length} bytes');
    final title = RegExp(r'<title>([^<]+)').firstMatch(resp.body);
    print('Title: ${title?.group(1)}');
    // Parse all th/td pairs
    final specs = <String, String>{};
    for (final m in RegExp(
      r'<th[^>]*>([^<]+)</th>\s*<td[^>]*>(.*?)</td>',
      dotAll: true,
    ).allMatches(resp.body)) {
      final key = m.group(1)!.replaceAll(':', '').trim();
      final value = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      if (key.isNotEmpty && value.isNotEmpty) specs[key] = value;
    }
    for (final e in specs.entries) {
      print('  ${e.key}: ${e.value}');
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 4: Fetch TechPowerUp GPU page for RTX 4090 (check if it has SSR data)
  print('\n\n=== TechPowerUp GPU Detail: RTX 4090 ===');
  try {
    // First, find the URL via Startpage
    final spResp = await http.post(
      Uri.parse('https://www.startpage.com/sp/search'),
      headers: {
        'User-Agent': ua,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'query=${Uri.encodeComponent("GeForce RTX 4090 site:techpowerup.com/gpu-specs")}',
    ).timeout(const Duration(seconds: 15));
    final gpuUrl = RegExp(
      r'(https?://www\.techpowerup\.com/gpu-specs/[^\s"&<]+\.c\d+)',
    ).firstMatch(spResp.body)?.group(1);
    print('GPU URL: $gpuUrl');

    if (gpuUrl != null) {
      await Future.delayed(const Duration(seconds: 1));
      final resp = await http.get(
        Uri.parse(gpuUrl),
        headers: {'User-Agent': ua, 'Accept': 'text/html'},
      ).timeout(const Duration(seconds: 15));
      print('Status: ${resp.statusCode}');
      print('Body: ${resp.body.length} bytes');
      final title = RegExp(r'<title>([^<]+)').firstMatch(resp.body);
      print('Title: ${title?.group(1)}');

      // Check for table/specs data
      final specs = <String, String>{};
      for (final m in RegExp(
        r'<th[^>]*>([^<]+)</th>\s*<td[^>]*>(.*?)</td>',
        dotAll: true,
      ).allMatches(resp.body)) {
        final key = m.group(1)!.replaceAll(':', '').trim();
        final value = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        if (key.isNotEmpty && value.isNotEmpty) specs[key] = value;
      }
      if (specs.isNotEmpty) {
        print('Server-side rendered specs:');
        for (final e in specs.entries) {
          print('  ${e.key}: ${e.value}');
        }
      } else {
        // Check for dl/dt/dd structure
        final dlSpecs = RegExp(r'<dt[^>]*>([^<]+)</dt>\s*<dd[^>]*>(.*?)</dd>', dotAll: true)
            .allMatches(resp.body);
        print('DL specs: ${dlSpecs.length}');

        // Check for JSON-LD
        final jsonLd = RegExp(r'<script type="application/ld\+json">(.*?)</script>', dotAll: true)
            .allMatches(resp.body);
        print('JSON-LD blocks: ${jsonLd.length}');
        for (final j in jsonLd) {
          print('  ${j.group(1)!.substring(0, j.group(1)!.length.clamp(0, 200))}');
        }

        // Check for __NEXT_DATA__
        if (resp.body.contains('__NEXT_DATA__')) {
          final ndMatch = RegExp(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true)
              .firstMatch(resp.body);
          if (ndMatch != null) {
            print('__NEXT_DATA__ found! Length: ${ndMatch.group(1)!.length}');
            print('First 500: ${ndMatch.group(1)!.substring(0, ndMatch.group(1)!.length.clamp(0, 500))}');
          }
        }

        // Check for div.specs or similar
        final specDivs = RegExp(r'class="[^"]*spec[^"]*"', caseSensitive: false)
            .allMatches(resp.body);
        print('Spec-related class elements: ${specDivs.length}');
        for (final s in specDivs.take(10)) {
          print('  ${s.group(0)}');
        }

        // Check noscript
        if (resp.body.contains('<noscript>')) {
          print('Has <noscript> tag (JS-required page)');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 5: Try TechPowerUp CPU main page with specific manufacturer filter
  print('\n\n=== TechPowerUp CPU Main - Check All CPU Links ===');
  try {
    final resp = await http
        .get(Uri.parse('https://www.techpowerup.com/cpu-specs/'),
            headers: {'User-Agent': ua})
        .timeout(const Duration(seconds: 15));
    final allLinks = RegExp(
      r'href="(/cpu-specs/[^"]+\.c\d+)"[^>]*>([^<]+)',
    ).allMatches(resp.body);
    print('Total CPU links on main page: ${allLinks.length}');
    // Check if i5-520M is there
    for (final m in allLinks) {
      final name = m.group(2)!.toLowerCase();
      if (name.contains('520m') || name.contains('i5-520')) {
        print('  Found: ${m.group(2)} → ${m.group(1)}');
      }
    }
    // Print some sample links
    print('Sample links:');
    for (final m in allLinks.take(10)) {
      print('  ${m.group(2)} → ${m.group(1)}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
