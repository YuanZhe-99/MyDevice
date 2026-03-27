// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  // ── TechPowerUp CPU Search (different approach) ──
  print('=== TechPowerUp CPU Search Page ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.techpowerup.com/cpu-specs/?mfgr=Intel&released=2024&sort=name'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final html = resp.body;
      // Look for CPU links in table
      final links = RegExp(r'<a href="(/cpu-specs/[^"]+\.c\d+)"[^>]*>([^<]+)</a>')
          .allMatches(html)
          .take(5)
          .toList();
      print('  Found ${links.length} CPU links');
      for (final l in links) {
        print('    ${l.group(2)} -> ${l.group(1)}');
      }
      // also check table structure
      final rows = RegExp(r'<tr[^>]*>').allMatches(html).length;
      print('  Total table rows: $rows');
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── TechPowerUp CPU Detail (correct URL) ──
  print('');
  print('=== TechPowerUp CPU Detail: Core Ultra 7 258V ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.techpowerup.com/cpu-specs/core-ultra-7-258v.c3285'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final html = resp.body;
      // Try multiple parsing patterns
      // Pattern 1: section + dl/dt/dd
      final dlMatches = RegExp(r'<dt>([^<]+)</dt>\s*<dd[^>]*>([^<]*(?:<[^>]+>[^<]*)*?)</dd>', dotAll: true)
          .allMatches(html).take(20);
      print('  dt/dd patterns: ${dlMatches.length}');
      for (final m in dlMatches) {
        final key = m.group(1)?.trim();
        final value = m.group(2)?.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        print('    $key: $value');
      }
      
      // Pattern 2: Look for section headings
      final sections = RegExp(r'<section[^>]*>\s*<h2[^>]*>([^<]+)</h2>', dotAll: true)
          .allMatches(html).toList();
      print('  Sections: ${sections.map((s) => s.group(1)).toList()}');
      
      // Pattern 3: th/td in spec tables
      final specTd = RegExp(r'<th[^>]*>([^<]+)</th>\s*<td[^>]*>(.*?)</td>', dotAll: true)
          .allMatches(html).take(20);
      print('  th/td pairs: ${specTd.length}');
      for (final m in specTd) {
        final key = m.group(1)?.trim();
        final value = m.group(2)?.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        print('    $key: $value');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── TechPowerUp GPU Detail ──
  print('');
  print('=== TechPowerUp GPU Detail: RTX 4090 ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.techpowerup.com/gpu-specs/geforce-rtx-4090.c3889'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final html = resp.body;
      final dlMatches = RegExp(r'<dt>([^<]+)</dt>\s*<dd[^>]*>([^<]*(?:<[^>]+>[^<]*)*?)</dd>', dotAll: true)
          .allMatches(html).take(20);
      print('  dt/dd patterns: ${dlMatches.length}');
      for (final m in dlMatches) {
        final key = m.group(1)?.trim();
        final value = m.group(2)?.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        print('    $key: $value');
      }
      
      final specTd = RegExp(r'<th[^>]*>([^<]+)</th>\s*<td[^>]*>(.*?)</td>', dotAll: true)
          .allMatches(html).take(20);
      print('  th/td pairs: ${specTd.length}');
      for (final m in specTd) {
        final key = m.group(1)?.trim();
        final value = m.group(2)?.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        print('    $key: $value');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── TechPowerUp GPU Search Page ──
  print('');
  print('=== TechPowerUp GPU Search Page ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.techpowerup.com/gpu-specs/?generation=GeForce+RTX+40&sort=name'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final html = resp.body;
      final links = RegExp(r'<a href="(/gpu-specs/[^"]+\.c\d+)"[^>]*>([^<]+)</a>')
          .allMatches(html)
          .take(5)
          .toList();
      print('  Found ${links.length} GPU links');
      for (final l in links) {
        print('    ${l.group(2)} -> ${l.group(1)}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Nanoreview API (used by many benchmark sites) ──
  print('');
  print('=== NanoReview API ===');
  try {
    final resp = await http.get(
      Uri.parse('https://nanoreview.net/en/search?q=Intel+Core+Ultra+7+258V'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── CPU-World ──
  print('');
  print('=== CPU-World ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.cpu-world.com/cgi-bin/Search.pl?search=Core+Ultra+7+258V'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final links = RegExp(r'<a[^>]*href="([^"]*CPUs[^"]*)"[^>]*>([^<]+)</a>')
          .allMatches(resp.body)
          .take(5);
      for (final l in links) {
        print('    ${l.group(2)} -> ${l.group(1)}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Wikipedia API (lightweight, reliable) ──
  print('');
  print('=== Wikipedia API: Intel Core Ultra 7 258V ===');
  try {
    final resp = await http.get(
      Uri.parse('https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=Intel+Core+Ultra+7+258V+processor&format=json&srlimit=3'),
      headers: {'User-Agent': _ua, 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}');
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final results = data['query']['search'] as List;
      for (final r in results) {
        print('    ${r['title']}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }
}
