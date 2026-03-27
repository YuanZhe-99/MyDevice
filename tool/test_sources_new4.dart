import 'dart:convert';
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

const googleBot =
    'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';

Future<void> main() async {
  // Test 1: TechPowerUp GPU page with Googlebot UA (SSR for crawlers?)
  print('=== TechPowerUp GPU - Googlebot UA ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.techpowerup.com/gpu-specs/geforce-rtx-4090.c3889'),
      headers: {'User-Agent': googleBot, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));
    print('Status: ${resp.statusCode}');
    print('Body: ${resp.body.length} bytes');
    // Check for th/td specs
    final specs = <String, String>{};
    for (final m in RegExp(
      r'<th[^>]*>([^<]+)</th>\s*<td[^>]*>(.*?)</td>',
      dotAll: true,
    ).allMatches(resp.body)) {
      final key = m.group(1)!.replaceAll(':', '').trim();
      final value = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      if (key.isNotEmpty && value.isNotEmpty) specs[key] = value;
    }
    print('TH/TD specs: ${specs.length}');
    for (final e in specs.entries) {
      print('  ${e.key}: ${e.value}');
    }

    // Check for any spec-like data in window.__INITIAL_STATE__ etc
    for (final pattern in [
      r'window\.__\w+\s*=\s*({.*?});',
      r'"architecture"\s*:\s*"([^"]+)"',
      r'"shaders"\s*:\s*"?(\d+)',
      r'"memorySize"\s*:\s*"([^"]+)"',
      r'"chip"\s*:\s*"([^"]+)"',
      r'"gpu_name"\s*:\s*"([^"]+)"',
    ]) {
      final match = RegExp(pattern, dotAll: true).firstMatch(resp.body);
      if (match != null) {
        final s = match.group(0)!;
        print('  Pattern "$pattern" matched: ${s.substring(0, s.length.clamp(0, 200))}');
      }
    }

    // Look for any JSON blocks in scripts
    for (final s in RegExp(r'<script[^>]*>(.*?)</script>', dotAll: true)
        .allMatches(resp.body)) {
      final content = s.group(1)!;
      if (content.contains('4090') || content.contains('AD102') ||
          content.contains('NVIDIA') || content.contains('shader')) {
        print('  Relevant script (${content.length} chars), first 300:');
        print('    ${content.substring(0, content.length.clamp(0, 300))}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 2: Notebookcheck GPU page
  print('\n\n=== Notebookcheck GPU Search ===');
  try {
    // Try Notebookcheck GPU page
    final resp = await http.get(
      Uri.parse('https://www.notebookcheck.net/NVIDIA-GeForce-RTX-4090-GPU-Benchmarks-and-Specs.564378.0.html'),
      headers: {'User-Agent': ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));
    print('Status: ${resp.statusCode}');
    print('Body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final title = RegExp(r'<title>([^<]+)').firstMatch(resp.body);
      print('Title: ${title?.group(1)}');
      // Check for specs table
      final specs = <String, String>{};
      for (final m in RegExp(
        r'<th[^>]*>([^<]+)</th>\s*<td[^>]*>(.*?)</td>',
        dotAll: true,
      ).allMatches(resp.body)) {
        final key = m.group(1)!.replaceAll(':', '').trim();
        final value = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        if (key.isNotEmpty && value.isNotEmpty) specs[key] = value;
      }
      print('Specs: ${specs.length}');
      for (final e in specs.entries) {
        print('  ${e.key}: ${e.value}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 3: Find Notebookcheck GPU page via search
  print('\n\n=== Startpage → Notebookcheck GPU ===');
  try {
    final resp = await http.post(
      Uri.parse('https://www.startpage.com/sp/search'),
      headers: {
        'User-Agent': ua,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'query=${Uri.encodeComponent("RTX 4090 GPU Benchmarks and Specs site:notebookcheck.net")}',
    ).timeout(const Duration(seconds: 15));
    print('Status: ${resp.statusCode}');
    final nbcLinks = RegExp(
      r'(https?://www\.notebookcheck\.net/[^\s"&<]+GPU[^\s"&<]+\.html)',
    ).allMatches(resp.body).map((m) => m.group(1)!).toSet();
    print('NBC GPU links: ${nbcLinks.length}');
    for (final l in nbcLinks.take(5)) {
      print('  $l');
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 4: Try fetching TechPowerUp GPU page's actual content
  // Maybe the data is in a CSS-styled table that we need different parsing for
  print('\n\n=== TechPowerUp GPU - Deep HTML analysis ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.techpowerup.com/gpu-specs/geforce-rtx-4090.c3889'),
      headers: {'User-Agent': ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));
    final body = resp.body;

    // Count various elements
    print('div count: ${RegExp(r'<div').allMatches(body).length}');
    print('table count: ${RegExp(r'<table').allMatches(body).length}');
    print('script count: ${RegExp(r'<script').allMatches(body).length}');
    print('style/link count: ${RegExp(r'<(?:style|link)').allMatches(body).length}');

    // Check for data attributes
    final dataAttrs = RegExp(r'data-(\w+)="([^"]+)"').allMatches(body);
    print('Data attributes:');
    for (final d in dataAttrs.take(20)) {
      print('  data-${d.group(1)}: ${d.group(2)}');
    }

    // Find all class names
    final classes = RegExp(r'class="([^"]+)"').allMatches(body)
        .map((m) => m.group(1)!).toSet();
    print('Unique classes (${classes.length}):');
    for (final c in classes.take(30)) {
      print('  $c');
    }

    // Look for structured data pattern: "label: value" in text content
    // Sometimes React apps render invisible text for SEO
    final h1s = RegExp(r'<h[1-6][^>]*>([^<]+)</h[1-6]>').allMatches(body);
    print('Headings:');
    for (final h in h1s.take(10)) {
      print('  ${h.group(1)}');
    }

    // Check meta tags for spec data
    final metas = RegExp(r'<meta[^>]*content="([^"]+)"[^>]*name="([^"]+)"')
        .allMatches(body);
    print('Meta tags:');
    for (final m in metas) {
      print('  ${m.group(2)}: ${m.group(1)}');
    }
    // Also og: meta tags
    final ogMetas = RegExp(r'<meta[^>]*property="([^"]+)"[^>]*content="([^"]+)"')
        .allMatches(body);
    for (final m in ogMetas) {
      print('  ${m.group(1)}: ${m.group(2)}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
