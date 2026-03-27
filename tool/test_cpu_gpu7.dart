// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

String _strip(String html) => html.replaceAll(RegExp(r'<[^>]+>'), '').trim();

Future<void> main() async {
  // ── Notebookcheck: What's in the 108KB Processor_Search ──
  print('=== Notebookcheck Processor_Search analysis ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.notebookcheck.net/Processor_Search.8222.0.html?model=Ryzen+9+7950X'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
    if (resp.statusCode == 200) {
      final html = resp.body;
      // Count all table rows
      final allTr = RegExp(r'<tr[^>]*>').allMatches(html).length;
      print('  All <tr> tags: $allTr');
      // Count tables
      final tables = RegExp(r'<table[^>]*>').allMatches(html).length;
      print('  Tables: $tables');
      // Look for forms
      final forms = RegExp(r'<form[^>]*action="([^"]*)"[^>]*>', dotAll: true)
          .allMatches(html).toList();
      print('  Forms: ${forms.length}');
      for (final f in forms) {
        print('    action: ${f.group(1)}');
      }
      // Look for input named "model"
      final inputs = RegExp(r'<input[^>]*name="(\w+)"[^>]*>', dotAll: true)
          .allMatches(html).toList();
      for (final i in inputs) {
        print('    input: ${i.group(1)}');
      }
      // Look for select elements
      final selects = RegExp(r'<select[^>]*name="(\w+)"[^>]*>', dotAll: true)
          .allMatches(html).toList();
      for (final s in selects) {
        print('    select: ${s.group(1)}');
      }
      // Check for ajax/fetch
      final ajax = RegExp(r'(fetch|XMLHttp|ajax)\s*\(', caseSensitive: false)
          .allMatches(html).length;
      print('  Ajax/fetch calls: $ajax');
      // Check if "Ryzen" appears in the body
      final ryzenCount = 'ryzen'.allMatches(html.toLowerCase()).length;
      print('  "ryzen" mentions: $ryzenCount');
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Try Laptop_Search for CPU specifically ──
  print('\n=== Notebookcheck Laptop_Search for CPU ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.notebookcheck.net/Laptop_Search.8223.0.html?model=Ryzen+9+7950X'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
    if (resp.statusCode == 200) {
      final html = resp.body;
      final rows = RegExp(r'<tr[^>]*class="[^"]*(?:odd|even)[^"]*"[^>]*>(.*?)</tr>', dotAll: true)
          .allMatches(html).take(5);
      print('  Found ${rows.length} rows');
      for (final r in rows) {
        final linkMatch = RegExp(r'<a[^>]*href="([^"]+)"[^>]*>([^<]+)</a>')
            .firstMatch(r.group(1)!);
        if (linkMatch != null) {
          final name = linkMatch.group(2);
          // Get inline specs
          final brIdx = r.group(1)!.indexOf('<br/>');
          if (brIdx > 0) {
            final specs = _strip(r.group(1)!.substring(brIdx + 5));
            print('    $name → $specs');
          } else {
            print('    $name');
          }
        }
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── DDG Instant Answer API ──
  print('\n=== DDG Instant Answer API ===');
  try {
    final resp = await http.get(
      Uri.parse('https://api.duckduckgo.com/?q=Intel+Core+Ultra+7+258V&format=json&no_html=1'),
      headers: {'User-Agent': _ua},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      print('  AbstractText: ${data['AbstractText']?.toString().substring(0, 200.clamp(0, (data['AbstractText']?.toString().length ?? 0)))}');
      print('  AbstractSource: ${data['AbstractSource']}');
      final related = data['RelatedTopics'] as List?;
      print('  Related topics: ${related?.length}');
      if (related != null) {
        for (final r in related.take(3)) {
          if (r is Map) {
            print('    ${r['Text']?.toString().substring(0, 100.clamp(0, (r['Text']?.toString().length ?? 0)))}');
          }
        }
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Try DDG HTML search (not lite) ──
  print('\n=== DDG HTML Search ===');
  try {
    final resp = await http.get(
      Uri.parse('https://html.duckduckgo.com/html/?q=${Uri.encodeComponent("Intel Core Ultra 7 258V specifications techpowerup")}'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
    if (resp.statusCode == 200) {
      // Extract result links
      final links = RegExp(r'<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>', dotAll: true)
          .allMatches(resp.body).take(5);
      print('  Results:');
      for (final l in links) {
        print('    ${_strip(l.group(2)!)} → ${l.group(1)}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── DDG HTML for GPU ──
  print('\n=== DDG HTML Search: GPU ===');
  try {
    final resp = await http.get(
      Uri.parse('https://html.duckduckgo.com/html/?q=${Uri.encodeComponent("NVIDIA RTX 4090 specifications techpowerup")}'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
    if (resp.statusCode == 200) {
      final links = RegExp(r'<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>', dotAll: true)
          .allMatches(resp.body).take(5);
      print('  Results:');
      for (final l in links) {
        print('    ${_strip(l.group(2)!)} → ${l.group(1)}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }
}
