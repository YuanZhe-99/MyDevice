import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  // Test 1: Notebookcheck review page spec structure
  print('=== Notebookcheck review page ===');
  try {
    final url = Uri.parse(
      'https://www.notebookcheck.net/Lenovo-ThinkPad-X1-Carbon-G13.908931.0.html',
    );
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(const Duration(seconds: 20));
    print('Status: ${r.statusCode}');
    print('Body: ${r.bodyBytes.length} bytes');
    if (r.statusCode == 200) {
      final html = utf8.decode(r.bodyBytes, allowMalformed: true);

      // Look for specs table / data-spec patterns
      final specTable = RegExp(
        r'<table[^>]*class="[^"]*(?:specs|nbc_table_rating|techtable)[^"]*"[^>]*>(.*?)</table>',
        dotAll: true,
      ).firstMatch(html);
      print('Specs table found: ${specTable != null}');

      // Look for table with specs
      final allTables = RegExp(r'<table[^>]*class="([^"]*)"', dotAll: true).allMatches(html);
      print('Tables with class:');
      final seen = <String>{};
      for (final t in allTables) {
        final cls = t.group(1)!;
        if (seen.add(cls)) {
          print('  $cls');
        }
      }

      // Look for key spec keywords in td elements
      final trPattern = RegExp(
        r'<tr[^>]*>\s*<td[^>]*>\s*(.*?)\s*</td>\s*<td[^>]*>\s*(.*?)\s*</td>',
        dotAll: true,
      );
      int specRowCount = 0;
      for (final tr in trPattern.allMatches(html)) {
        final label = tr.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim().toLowerCase();
        final value = tr.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        if (value.isEmpty || value.length > 500) continue;
        if (label.contains('processor') || label.contains('cpu') ||
            label.contains('gpu') || label.contains('graphic') ||
            label.contains('memory') || label.contains('ram') ||
            label.contains('storage') || label.contains('display') ||
            label.contains('screen') || label.contains('battery') ||
            label.contains('operating') || label.contains('resolution') ||
            label.contains('ssd') || label.contains('hard')) {
          specRowCount++;
          if (specRowCount <= 20) {
            print('\n  [$label]: $value');
          }
        }
      }
      print('\nTotal spec-related rows: $specRowCount');

      // Check for image
      final imgMatch = RegExp(
        r'<img[^>]*src="(https?://[^"]*)"[^>]*alt="[^"]*ThinkPad[^"]*"',
        caseSensitive: false,
      ).firstMatch(html);
      print('\nImage: ${imgMatch?.group(1)}');

      // Also look for structured data (JSON-LD)
      final jsonLd = RegExp(
        r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
        dotAll: true,
      ).allMatches(html);
      print('\nJSON-LD blocks: ${jsonLd.length}');
      for (final j in jsonLd.take(2)) {
        final text = j.group(1)!.trim();
        print('  ${text.substring(0, text.length.clamp(0, 500))}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 2: Notebookcheck phone review
  print('\n\n=== Notebookcheck phone search ===');
  try {
    final url = Uri.parse(
      'https://www.notebookcheck.net/Laptop_Search.8223.0.html'
      '?model=${Uri.encodeComponent("iPhone 15 Pro")}',
    );
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(const Duration(seconds: 15));
    final html = utf8.decode(r.bodyBytes, allowMalformed: true);
    final trs = RegExp(
      r'<tr[^>]*class="[^"]*(?:odd|even)[^"]*"[^>]*>(.*?)</tr>',
      dotAll: true,
    ).allMatches(html);
    print('Total rows: ${trs.length}');
    int count = 0;
    for (final tr in trs) {
      final row = tr.group(1)!;
      // Skip empty rows
      if (row.contains('nb_model') && row.contains('colspan')) continue;
      count++;
      if (count <= 5) {
        final cleaned = row.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'&nbsp;'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        print('  $cleaned');
      }
    }
    print('Non-empty rows: $count');
  } catch (e) {
    print('Error: $e');
  }

  // Test 3: Notebookcheck Samsung Galaxy search
  print('\n\n=== Notebookcheck Galaxy S24 search ===');
  try {
    final url = Uri.parse(
      'https://www.notebookcheck.net/Laptop_Search.8223.0.html'
      '?model=${Uri.encodeComponent("Galaxy S24 Ultra")}',
    );
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(const Duration(seconds: 15));
    final html = utf8.decode(r.bodyBytes, allowMalformed: true);
    final trs = RegExp(
      r'<tr[^>]*class="[^"]*(?:odd|even)[^"]*"[^>]*>(.*?)</tr>',
      dotAll: true,
    ).allMatches(html);
    int count = 0;
    for (final tr in trs) {
      final row = tr.group(1)!;
      if (row.contains('nb_model') && row.contains('colspan')) continue;
      count++;
      if (count <= 5) {
        // Extract link and text
        final linkMatch = RegExp(r'href="([^"]+)"[^>]*>([^<]+)</a>').firstMatch(row);
        if (linkMatch != null) {
          print('  ${linkMatch.group(2)} -> ${linkMatch.group(1)}');
          // Get specs part after <br/>
          final brIdx = row.indexOf('<br/>');
          if (brIdx > 0) {
            final specs = row.substring(brIdx + 5).replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&nbsp;', ' ').trim();
            print('    Specs: $specs');
          }
        }
      }
    }
    print('Non-empty rows: $count');
  } catch (e) {
    print('Error: $e');
  }
}
