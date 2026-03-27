// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

String _strip(String html) => html.replaceAll(RegExp(r'<[^>]+>'), '').trim();

Future<void> main() async {
  // ── PassMark CPU detail structure ──
  print('=== PassMark CPU Detail Page ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.cpubenchmark.net/cpu.php?cpu=AMD+Ryzen+9+7950X&id=4904'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
    if (resp.statusCode == 200) {
      final html = resp.body;
      // Check for structured data
      final jsonLd = RegExp(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', dotAll: true)
          .allMatches(html);
      for (final m in jsonLd) {
        print('  JSON-LD: ${m.group(1)?.substring(0, 200.clamp(0, m.group(1)!.length))}');
      }
      // Check for spec spans/divs
      final descIdx = html.indexOf('Class:');
      if (descIdx >= 0) {
        print('  Found "Class:" at $descIdx');
        print('    context: ${html.substring(descIdx, (descIdx + 500).clamp(0, html.length))}');
      }
      // Check for "Cores:" text
      final coresIdx = html.indexOf('Cores');
      if (coresIdx >= 0) {
        print('  Found "Cores" at $coresIdx');
        final start = (coresIdx - 100).clamp(0, html.length);
        final end = (coresIdx + 300).clamp(0, html.length);
        print('    context: ${html.substring(start, end)}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── PassMark CPU search/autocomplete ──
  print('\n=== PassMark CPU autocomplete ===');
  final pmEndpoints = [
    'https://www.cpubenchmark.net/cpu_mega_page.html',
  ];
  for (final url in pmEndpoints) {
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _ua, 'Accept': 'text/html'},
      ).timeout(const Duration(seconds: 10));
      print('  $url: ${resp.statusCode}  ${resp.body.length} bytes');
      if (resp.statusCode == 200) {
        // look for JSON data or script with CPU data
        final scriptData = RegExp(r'var\s+(\w+)\s*=\s*(\[.*?\]);', dotAll: true)
            .allMatches(resp.body).take(3);
        for (final m in scriptData) {
          final name = m.group(1);
          final data = m.group(2)!;
          print('    var $name = [${data.length} chars]');
          print('    first 200: ${data.substring(0, 200.clamp(0, data.length))}');
        }
      }
    } catch (e) {
      print('  $url → ERROR: $e');
    }
  }

  // ── Geekbench CPU search ──
  print('\n=== Geekbench Search API ===');
  try {
    final resp = await http.get(
      Uri.parse('https://browser.geekbench.com/v6/cpu/search?q=Ryzen+9+7950X'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
    if (resp.statusCode == 200) {
      final links = RegExp(r'<a[^>]*href="(/v6/cpu/\d+)"[^>]*>([^<]+)</a>')
          .allMatches(resp.body).take(5);
      for (final l in links) {
        print('    ${l.group(2)} -> ${l.group(1)}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Geekbench Processor list with search ──
  print('\n=== Geekbench Processor Benchmarks (chips/search) ===');
  try {
    final resp = await http.get(
      Uri.parse('https://browser.geekbench.com/processor-benchmarks?q=Ryzen+9+7950X'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
    if (resp.statusCode == 200) {
      final html = resp.body;
      // Look for processor names with links
      final links = RegExp(r'<a[^>]*href="(/processor/\d+)"[^>]*>([^<]+)</a>')
          .allMatches(html).take(5);
      for (final l in links) {
        print('    ${l.group(2)} -> ${l.group(1)}');
      }
      // Also try alternate patterns
      final links2 = RegExp(r'<td[^>]*>.*?<a[^>]*href="([^"]+)"[^>]*>([^<]+)</a>', dotAll: true)
          .allMatches(html).take(5);
      for (final l in links2) {
        print('    [td/a] ${l.group(2)} -> ${l.group(1)}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Notebookcheck processor search ──
  print('\n=== Notebookcheck Processor Search ===');
  try {
    // Try the processor comparison with search
    final resp = await http.get(
      Uri.parse('https://www.notebookcheck.net/Processor_Search.8222.0.html?model=Ryzen+9+7950X'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
    if (resp.statusCode == 200) {
      final html = resp.body;
      // Look for table rows like Laptop_Search
      final rows = RegExp(r'<tr[^>]*class="[^"]*(?:odd|even)[^"]*"[^>]*>(.*?)</tr>', dotAll: true)
          .allMatches(html).take(5);
      print('  Found ${rows.length} result rows');
      for (final r in rows) {
        final linkMatch = RegExp(r'<a[^>]*href="([^"]+)"[^>]*>([^<]+)</a>')
            .firstMatch(r.group(1)!);
        if (linkMatch != null) {
          print('    ${linkMatch.group(2)} -> ${linkMatch.group(1)}');
        }
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Notebookcheck GPU search ──
  print('\n=== Notebookcheck GPU Search ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.notebookcheck.net/GPU_Search.8222.0.html?model=RTX+4090'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
    if (resp.statusCode == 200) {
      final html = resp.body;
      final rows = RegExp(r'<tr[^>]*class="[^"]*(?:odd|even)[^"]*"[^>]*>(.*?)</tr>', dotAll: true)
          .allMatches(html).take(5);
      print('  Found ${rows.length} result rows');
      for (final r in rows) {
        final linkMatch = RegExp(r'<a[^>]*href="([^"]+)"[^>]*>([^<]+)</a>')
            .firstMatch(r.group(1)!);
        if (linkMatch != null) {
          print('    ${linkMatch.group(2)} -> ${linkMatch.group(1)}');
        }
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }
}
