// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  // ── Intel ARK ──
  print('=== Intel ARK Autocomplete ===');
  // Intel ARK has a search API
  try {
    final resp = await http.get(
      Uri.parse(
          'https://www.intel.com/content/dam/www/global/ark/assets/data/ark-search.json'),
      headers: {'User-Agent': _ua},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200 && resp.body.length > 100) {
      print('  first 300: ${resp.body.substring(0, 300)}');
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  print('');
  print('=== Intel ARK Search API ===');
  try {
    final resp = await http.get(
      Uri.parse(
          'https://www.intel.com/content/www/us/en/ark/search.html?_charset_=UTF-8&q=Core+Ultra+7+258V'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
  } catch (e) {
    print('  ERROR: $e');
  }

  // Intel ARK has a typeahead endpoint
  print('');
  print('=== Intel ARK Typeahead ===');
  try {
    final resp = await http.get(
      Uri.parse(
          'https://www.intel.com/libs/apps/intel/arksearch/autocomplete?_charset_=UTF-8&locale=en_us&input=Core Ultra 7'),
      headers: {'User-Agent': _ua, 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200 && resp.body.length < 5000) {
      print('  body: ${resp.body}');
    } else if (resp.statusCode == 200) {
      print('  first 500: ${resp.body.substring(0, 500)}');
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── AMD Product Search ──
  print('');
  print('=== AMD Product Database ===');
  try {
    final resp = await http.get(
      Uri.parse(
          'https://www.amd.com/en/products/processors/search?query=Ryzen+9+7950X'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── TechPowerUp CPU DB ──
  print('');
  print('=== TechPowerUp CPU DB ===');
  try {
    final resp = await http.get(
      Uri.parse(
          'https://www.techpowerup.com/cpu-specs/core-ultra-7-258v.c3285'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      // Check for spec table
      final html = resp.body;
      final tableMatch = RegExp(r'<table[^>]*class="[^"]*specs[^"]*"').firstMatch(html);
      print('  Has specs table: ${tableMatch != null}');
      // Count spec rows
      final specRows = RegExp(r'<th>([^<]+)</th>\s*<td>([^<]+)</td>', dotAll: true);
      final matches = specRows.allMatches(html).take(10).toList();
      for (final m in matches) {
        print('    ${m.group(1)}: ${m.group(2)}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── TechPowerUp CPU Search ──
  print('');
  print('=== TechPowerUp CPU Search ===');
  try {
    final resp = await http.get(
      Uri.parse(
          'https://www.techpowerup.com/cpu-specs/?ajaxsrch=Ryzen%209%207950X'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final html = resp.body;
      // Look for result links
      final links = RegExp(r'<a href="(/cpu-specs/[^"]+)"[^>]*>([^<]+)</a>')
          .allMatches(html)
          .take(5)
          .toList();
      print('  Found ${links.length} CPU links');
      for (final l in links) {
        print('    ${l.group(2)} -> ${l.group(1)}');
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── TechPowerUp GPU DB ──  
  print('');
  print('=== TechPowerUp GPU DB ===');
  try {
    final resp = await http.get(
      Uri.parse(
          'https://www.techpowerup.com/gpu-specs/?ajaxsrch=RTX%204090'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final html = resp.body;
      final links = RegExp(r'<a href="(/gpu-specs/[^"]+)"[^>]*>([^<]+)</a>')
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

  // ── TechPowerUp GPU Detail ──  
  print('');
  print('=== TechPowerUp GPU Detail ===');
  try {
    final resp = await http.get(
      Uri.parse(
          'https://www.techpowerup.com/gpu-specs/geforce-rtx-4090.c3889'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final html = resp.body;
      final specRows = RegExp(r'<dt>([^<]+)</dt>\s*<dd>([^<]+)</dd>', dotAll: true);
      final matches = specRows.allMatches(html).take(15).toList();
      if (matches.isEmpty) {
        // Try th/td
        final thTd = RegExp(r'<th>([^<]+)</th>\s*<td>([^<]+)</td>', dotAll: true);
        final matches2 = thTd.allMatches(html).take(15).toList();
        for (final m in matches2) {
          print('    ${m.group(1)?.trim()}: ${m.group(2)?.trim()}');
        }
      } else {
        for (final m in matches) {
          print('    ${m.group(1)?.trim()}: ${m.group(2)?.trim()}');
        }
      }
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── Notebookcheck CPU Search ──
  print('');
  print('=== Notebookcheck Processor DB ===');
  try {
    // Notebookcheck has a processor comparison page
    final resp = await http.get(
      Uri.parse(
          'https://www.notebookcheck.net/Mobile-Processors-Benchmark-List.2436.0.html'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    print('  status: ${resp.statusCode}  body: ${resp.body.length} bytes');
  } catch (e) {
    print('  ERROR: $e');
  }
}
