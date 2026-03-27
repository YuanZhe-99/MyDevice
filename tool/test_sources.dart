import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  // Test 1: DeviceSpecifications brand page - check structure
  print('=== DeviceSpecifications brand page ===');
  try {
    final url = Uri.parse('https://www.devicespecifications.com/en/brand/apple');
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
    }).timeout(const Duration(seconds: 15));
    print('Status: ${r.statusCode}');
    final html = utf8.decode(r.bodyBytes, allowMalformed: true);
    // Look for model links
    final modelLinks = RegExp(r'href="(/en/[^"]+)"').allMatches(html);
    print('All /en/ links: ${modelLinks.length}');
    final seen = <String>{};
    for (final l in modelLinks) {
      final href = l.group(1)!;
      if (seen.add(href)) {
        if (seen.length <= 15) print('  $href');
      }
    }
    // Also look for any <a> with title text near "iPhone"
    final iphoneLinks = RegExp(
      r'<a[^>]*href="(/en/[^"]+)"[^>]*>\s*([^<]*iPhone[^<]*)\s*</a>',
      caseSensitive: false,
    ).allMatches(html);
    print('\niPhone links: ${iphoneLinks.length}');
    for (final l in iphoneLinks.take(10)) {
      print('  ${l.group(2)?.trim()} -> ${l.group(1)}');
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 2: DeviceSpecifications model page (if we find one)
  print('\n=== DeviceSpecifications model page ===');
  try {
    // Try a specific model URL pattern
    final url = Uri.parse(
      'https://www.devicespecifications.com/en/model/d0556358',
    );
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
    }).timeout(const Duration(seconds: 15));
    print('Status: ${r.statusCode}');
    print('Body: ${r.bodyBytes.length} bytes');
  } catch (e) {
    print('Error: $e');
  }

  // Test 3: Laptopmedia
  print('\n=== Laptopmedia ===');
  try {
    final url = Uri.parse(
      'https://laptopmedia.com/?s=${Uri.encodeComponent("ThinkPad X1 Carbon")}',
    );
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
    }).timeout(const Duration(seconds: 15));
    print('Status: ${r.statusCode}');
    print('Body: ${r.bodyBytes.length} bytes');
    if (r.statusCode == 200) {
      final html = utf8.decode(r.bodyBytes, allowMalformed: true);
      final links = RegExp(
        r'<a[^>]*href="(https?://laptopmedia\.com/[^"]+)"[^>]*>\s*([^<]{5,}?)\s*</a>',
      ).allMatches(html);
      print('Article links: ${links.length}');
      final seen = <String>{};
      for (final l in links) {
        final title = l.group(2)!.trim();
        if (seen.add(title) && seen.length <= 10) {
          print('  $title -> ${l.group(1)}');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 4: CPU-Monkey
  print('\n=== CPU-Monkey ===');
  try {
    final url = Uri.parse(
      'https://www.cpu-monkey.com/en/cpu_search?q=${Uri.encodeComponent("Apple A17 Pro")}',
    );
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
    }).timeout(const Duration(seconds: 15));
    print('Status: ${r.statusCode}');
    print('Body: ${r.bodyBytes.length} bytes');
    if (r.statusCode == 200) {
      final html = utf8.decode(r.bodyBytes, allowMalformed: true);
      final links = RegExp(r'href="(/en/cpu-[^"]+)"').allMatches(html);
      print('CPU links: ${links.length}');
      for (final l in links.take(10)) {
        print('  ${l.group(1)}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 5: Notebookcheck - look at search page HTML for AJAX hints
  print('\n=== Notebookcheck search page JS analysis ===');
  try {
    final url = Uri.parse('https://www.notebookcheck.net/Search.8222.0.html');
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
    }).timeout(const Duration(seconds: 15));
    print('Status: ${r.statusCode}');
    final html = utf8.decode(r.bodyBytes, allowMalformed: true);
    // Look for search-related JavaScript
    final ajaxPattern = RegExp(r'(ajax|fetch|XMLHttpRequest|search.*url|api.*search)[^"<>\n]{0,200}', caseSensitive: false);
    final matches = ajaxPattern.allMatches(html);
    print('Ajax/fetch references: ${matches.length}');
    for (final m in matches.take(10)) {
      print('  ${m.group(0)?.replaceAll(RegExp(r'\s+'), ' ').trim()}');
    }
    // Look for form action
    final formPattern = RegExp(r'<form[^>]*action="([^"]*)"[^>]*>', dotAll: true);
    final forms = formPattern.allMatches(html);
    print('Forms: ${forms.length}');
    for (final f in forms) {
      print('  action="${f.group(1)}"');
    }
    // Look for Google CSE
    final csePattern = RegExp(r'google.*search|cse\.google|cx=', caseSensitive: false);
    final cseMatches = csePattern.allMatches(html);
    print('Google CSE refs: ${cseMatches.length}');
  } catch (e) {
    print('Error: $e');
  }

  // Test 6: Try Notebook-check.com (alternate domain)
  print('\n=== Notebookcheck.com search ===');
  try {
    final url = Uri.parse(
      'https://www.notebookcheck.com/?ns_search=${Uri.encodeComponent("ThinkPad X1 Carbon")}',
    );
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
    }).timeout(const Duration(seconds: 15));
    print('Status: ${r.statusCode}');
    print('Body: ${r.bodyBytes.length} bytes');
  } catch (e) {
    print('Error: $e');
  }

  // Test 7: try phonescoop / specphone
  print('\n=== SpecPhone ===');
  try {
    final url = Uri.parse(
      'https://specphone.com/l/en/search.html?q=${Uri.encodeComponent("iPhone 15 Pro")}',
    );
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
    }).timeout(const Duration(seconds: 15));
    print('Status: ${r.statusCode}');
    print('Body: ${r.bodyBytes.length} bytes');
  } catch (e) {
    print('Error: $e');
  }

  // Test 8: Phone-specs.com
  print('\n=== Phone-Specs ===');
  try {
    final url = Uri.parse(
      'https://phone-specs.com/search-phone/${Uri.encodeComponent("iPhone 15 Pro")}',
    );
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
    }).timeout(const Duration(seconds: 15));
    print('Status: ${r.statusCode}');
    print('Body: ${r.bodyBytes.length} bytes');
  } catch (e) {
    print('Error: $e');
  }

  // Test 9: GSMArena with laptop search (scope test)
  print('\n=== GSMArena laptop search ===');
  try {
    final url = Uri.parse(
      'https://www.gsmarena.com/results.php3'
      '?sQuickSearch=yes&sName=${Uri.encodeComponent("ThinkPad X1 Carbon")}',
    );
    final r = await http.get(url, headers: {
      'User-Agent': ua,
      'Accept': 'text/html',
    }).timeout(const Duration(seconds: 15));
    print('Status: ${r.statusCode}');
    final html = utf8.decode(r.bodyBytes, allowMalformed: true);
    final makers = RegExp(r'class="makers"').allMatches(html);
    print('makers div: ${makers.length}');
    if (makers.isEmpty) {
      // Show error/no results message
      final msg = RegExp(r'<div[^>]*class="[^"]*center-stage[^"]*"[^>]*>(.*?)</div>', dotAll: true).firstMatch(html);
      if (msg != null) print('Message: ${msg.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim()}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
