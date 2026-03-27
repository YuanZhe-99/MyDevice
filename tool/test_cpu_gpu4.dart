// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

String _strip(String html) => html.replaceAll(RegExp(r'<[^>]+>'), '').trim();

Future<void> main() async {
  // ── DDG → TechPowerUp CPU flow ──
  print('=== DDG → TechPowerUp CPU ===');
  final cpuQueries = [
    'Intel Core Ultra 7 258V',
    'AMD Ryzen 9 7950X',
    'Apple M3 Max',
    'Qualcomm Snapdragon 8 Gen 3',
  ];
  for (final q in cpuQueries) {
    print('\n--- $q ---');
    try {
      final ddg = await http.post(
        Uri.parse('https://lite.duckduckgo.com/lite/'),
        headers: {'User-Agent': _ua, 'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'q=${Uri.encodeComponent("$q site:techpowerup.com/cpu-specs")}&kl=us-en',
      ).timeout(const Duration(seconds: 10));
      
      if (ddg.statusCode != 200) {
        print('  DDG: ${ddg.statusCode}');
        continue;
      }
      
      // Extract URLs - DDG Lite has: <a rel="nofollow" href="URL" class='result-link'>
      final urlMatches = RegExp(r'''<a[^>]*class='result-link'[^>]*href="([^"]+)"''')
          .allMatches(ddg.body);
      
      // Also try single-quoted href
      final urlMatches2 = RegExp(r"""<a[^>]*class='result-link'[^>]*href='([^']+)'""")
          .allMatches(ddg.body);
      
      String? tpuUrl;
      for (final m in [...urlMatches, ...urlMatches2]) {
        final url = m.group(1)!;
        if (url.contains('techpowerup.com/cpu-specs/') && url.contains('.c')) {
          tpuUrl = url;
          break;
        }
      }
      
      if (tpuUrl == null) {
        // Try extracting href differently
        final allLinks = RegExp(r'href="(https?://www\.techpowerup\.com/cpu-specs/[^"]+)"')
            .allMatches(ddg.body);
        final allLinks2 = RegExp(r"href='(https?://www\.techpowerup\.com/cpu-specs/[^']+)'")
            .allMatches(ddg.body);
        for (final m in [...allLinks, ...allLinks2]) {
          tpuUrl = m.group(1);
          break;
        }
      }
      
      if (tpuUrl == null) {
        print('  No TechPowerUp CPU URL found in DDG');
        // Debug: extract all result links
        final debug = RegExp(r'''class='result-link'[^>]*>([^<]+)</a>''')
            .allMatches(ddg.body).take(3);
        for (final d in debug) {
          print('    result: ${d.group(1)}');
        }
        // Extract all hrefs around result-link
        final snippet = ddg.body;
        final rlIdx = snippet.indexOf("result-link");
        if (rlIdx >= 0) {
          final start = (rlIdx - 300).clamp(0, snippet.length);
          final end = (rlIdx + 300).clamp(0, snippet.length);
          print('    context: ${snippet.substring(start, end)}');
        }
        continue;
      }
      
      print('  TPU URL: $tpuUrl');
      
      // Fetch TechPowerUp page
      final resp = await http.get(
        Uri.parse(tpuUrl),
        headers: {'User-Agent': _ua, 'Accept': 'text/html'},
      ).timeout(const Duration(seconds: 10));
      
      if (resp.statusCode != 200) {
        print('  TPU: ${resp.statusCode}');
        continue;
      }
      
      // Parse specs
      final html = resp.body;
      final specs = RegExp(r'<th[^>]*>([^<]+)</th>\s*<td[^>]*>(.*?)</td>', dotAll: true)
          .allMatches(html);
      for (final m in specs) {
        final key = _strip(m.group(1)!);
        final value = _strip(m.group(2)!);
        if (key.isNotEmpty && value.isNotEmpty) {
          print('    $key: $value');
        }
      }
    } catch (e) {
      print('  ERROR: $e');
    }
  }

  // ── DDG → GPU search ──
  print('\n\n=== DDG → GPU Search ===');
  final gpuQueries = [
    'NVIDIA GeForce RTX 4090',
    'AMD Radeon RX 7900 XTX',
    'Intel Arc Graphics 140V',
    'Apple M3 Max GPU',
  ];
  for (final q in gpuQueries) {
    print('\n--- $q ---');
    try {
      // Try TechPowerUp GPU
      final ddg = await http.post(
        Uri.parse('https://lite.duckduckgo.com/lite/'),
        headers: {'User-Agent': _ua, 'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'q=${Uri.encodeComponent("$q specifications architecture")}&kl=us-en',
      ).timeout(const Duration(seconds: 10));
      
      if (ddg.statusCode != 200) {
        print('  DDG: ${ddg.statusCode}');
        continue;
      }
      
      final results = RegExp(r'''class='result-link'[^>]*>([^<]+)</a>''')
          .allMatches(ddg.body).take(5);
      for (final r in results) {
        print('    ${r.group(1)}');
      }
    } catch (e) {
      print('  ERROR: $e');
    }
  }
}
