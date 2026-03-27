// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

String _strip(String html) => html.replaceAll(RegExp(r'<[^>]+>'), '').trim();

Future<void> main() async {
  // ── Wikipedia API: search + parse infobox ──
  print('=== Wikipedia: Search CPU ===');
  for (final q in [
    'Intel Core Ultra 7 258V',
    'AMD Ryzen 9 7950X', 
    'Apple M3 Max',
    'Qualcomm Snapdragon 8 Gen 3',
  ]) {
    print('\n--- $q ---');
    try {
      // Step 1: Search
      final searchResp = await http.get(
        Uri.parse('https://en.wikipedia.org/w/api.php?'
            'action=query&list=search&format=json'
            '&srsearch=${Uri.encodeComponent("$q processor")}'
            '&srlimit=3'),
        headers: {'User-Agent': '$_ua (MyDevice App)'},
      ).timeout(const Duration(seconds: 10));
      
      if (searchResp.statusCode != 200) continue;
      final searchData = jsonDecode(searchResp.body);
      final results = searchData['query']['search'] as List;
      
      if (results.isEmpty) {
        print('  No results');
        continue;
      }
      
      // Use first result
      final title = results[0]['title'] as String;
      print('  Article: $title');
      
      // Step 2: Get article wikitext (for infobox parsing)
      final contentResp = await http.get(
        Uri.parse('https://en.wikipedia.org/w/api.php?'
            'action=parse&format=json&prop=wikitext'
            '&page=${Uri.encodeComponent(title)}'),
        headers: {'User-Agent': '$_ua (MyDevice App)'},
      ).timeout(const Duration(seconds: 10));
      
      if (contentResp.statusCode != 200) continue;
      final contentData = jsonDecode(contentResp.body);
      final wikitext = contentData['parse']?['wikitext']?['*'] as String? ?? '';
      
      // Parse infobox
      final infoboxMatch = RegExp(r'\{\{[Ii]nfobox.*?\n(.*?)\n\}\}', dotAll: true)
          .firstMatch(wikitext);
      
      if (infoboxMatch == null) {
        print('  No infobox found');
        // Try looking for specific fields in plaintext
        final coreMatch = RegExp(r'core.*?(\d+).*?core', caseSensitive: false)
            .firstMatch(wikitext);
        if (coreMatch != null) print('  core ref: ${coreMatch.group(0)}');
        continue;
      }
      
      final infoboxContent = infoboxMatch.group(1)!;
      // Extract | key = value pairs
      final pairs = RegExp(r'\|\s*(\w[\w\s]*?)\s*=\s*(.+?)(?=\n\||\n\}\}|$)', dotAll: true)
          .allMatches(infoboxContent);
      
      for (final p in pairs) {
        final key = p.group(1)!.trim();
        var value = p.group(2)!.trim();
        // Clean up wiki markup
        value = value
            .replaceAll(RegExp(r'\[\[([^\]|]+\|)?([^\]]+)\]\]'), r'$2')
            .replaceAll(RegExp(r'\{\{[^}]+\}\}'), '')
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .trim();
        if (value.isNotEmpty && value.length < 200) {
          print('    $key: $value');
        }
      }
    } catch (e) {
      print('  ERROR: $e');
    }
  }

  // ── Wikipedia: GPU architectures ──
  print('\n\n=== Wikipedia: GPU Search ===');
  for (final q in [
    'NVIDIA GeForce RTX 4090',
    'AMD Radeon RX 7900 XTX',
    'Intel Arc Graphics 140V',
    'Apple M3 Max GPU',
  ]) {
    print('\n--- $q ---');
    try {
      final searchResp = await http.get(
        Uri.parse('https://en.wikipedia.org/w/api.php?'
            'action=query&list=search&format=json'
            '&srsearch=${Uri.encodeComponent(q)}'
            '&srlimit=3'),
        headers: {'User-Agent': '$_ua (MyDevice App)'},
      ).timeout(const Duration(seconds: 10));
      
      if (searchResp.statusCode != 200) continue;
      final searchData = jsonDecode(searchResp.body);
      final results = searchData['query']['search'] as List;
      
      if (results.isEmpty) { print('  No results'); continue; }
      
      final title = results[0]['title'] as String;
      print('  Article: $title');
      
      final contentResp = await http.get(
        Uri.parse('https://en.wikipedia.org/w/api.php?'
            'action=parse&format=json&prop=wikitext'
            '&page=${Uri.encodeComponent(title)}'),
        headers: {'User-Agent': '$_ua (MyDevice App)'},
      ).timeout(const Duration(seconds: 10));
      
      if (contentResp.statusCode != 200) continue;
      final contentData = jsonDecode(contentResp.body);
      final wikitext = contentData['parse']?['wikitext']?['*'] as String? ?? '';
      
      final infoboxMatch = RegExp(r'\{\{[Ii]nfobox.*?\n(.*?)\n\}\}', dotAll: true)
          .firstMatch(wikitext);
      
      if (infoboxMatch == null) {
        print('  No infobox found');
        continue;
      }
      
      final infoboxContent = infoboxMatch.group(1)!;
      final pairs = RegExp(r'\|\s*(\w[\w\s]*?)\s*=\s*(.+?)(?=\n\||\n\}\}|$)', dotAll: true)
          .allMatches(infoboxContent);
      
      for (final p in pairs) {
        final key = p.group(1)!.trim();
        var value = p.group(2)!.trim();
        value = value
            .replaceAll(RegExp(r'\[\[([^\]|]+\|)?([^\]]+)\]\]'), r'$2')
            .replaceAll(RegExp(r'\{\{[^}]+\}\}'), '')
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .trim();
        if (value.isNotEmpty && value.length < 200) {
          print('    $key: $value');
        }
      }
    } catch (e) {
      print('  ERROR: $e');
    }
  }

  // ── Notebookcheck AJAX CPU search ──
  print('\n\n=== Notebookcheck AJAX CPU Search ===');
  try {
    // The form has input name="ajax_getgpu_cpu" - try POST with this
    final resp = await http.post(
      Uri.parse('https://www.notebookcheck.net/Laptop_Search.8223.0.html'),
      headers: {
        'User-Agent': _ua,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: 'ajax_getgpu_cpu=Core+Ultra+7+258V&modelSearchAjax_2=1',
    ).timeout(const Duration(seconds: 15));
    print('  status: ${resp.statusCode}  size: ${resp.body.length}');
    if (resp.statusCode == 200 && resp.body.length < 5000) {
      print('  body: ${resp.body.substring(0, resp.body.length.clamp(0, 1000))}');
    } else if (resp.statusCode == 200) {
      print('  first 500: ${resp.body.substring(0, 500)}');
    }
  } catch (e) {
    print('  ERROR: $e');
  }
}
