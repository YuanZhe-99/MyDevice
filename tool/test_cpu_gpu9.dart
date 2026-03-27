// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  // ── Check TechPowerUp GPU for embedded JSON/NEXT_DATA ──
  print('=== TechPowerUp GPU: Embedded Data ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.techpowerup.com/gpu-specs/geforce-rtx-4090.c3889'),
      headers: {'User-Agent': _ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 10));
    final html = resp.body;
    
    // Check for __NEXT_DATA__ (Next.js)
    final nextData = RegExp(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true)
        .firstMatch(html);
    if (nextData != null) {
      print('  Found __NEXT_DATA__');
      final data = jsonDecode(nextData.group(1)!);
      print('  Keys: ${(data as Map).keys.toList()}');
    } else {
      print('  No __NEXT_DATA__');
    }
    
    // Check for any JSON in script tags
    final scripts = RegExp(r'<script[^>]*>(.*?)</script>', dotAll: true)
        .allMatches(html).toList();
    print('  Total script tags: ${scripts.length}');
    for (int i = 0; i < scripts.length; i++) {
      final content = scripts[i].group(1)!.trim();
      if (content.isNotEmpty && content.length < 50) {
        print('    script[$i]: $content');
      } else if (content.contains('RTX') || content.contains('4090') || content.contains('Ada')) {
        print('    script[$i]: contains target data (${content.length} chars)');
        // Print snippet around the match
        final idx = content.indexOf('4090');
        if (idx >= 0) {
          final start = (idx - 100).clamp(0, content.length);
          final end = (idx + 200).clamp(0, content.length);
          print('      ...${content.substring(start, end)}...');
        }
      }
    }
    
    // Check <noscript> content
    final noscript = RegExp(r'<noscript>(.*?)</noscript>', dotAll: true)
        .allMatches(html).toList();
    print('  noscript tags: ${noscript.length}');
    for (final ns in noscript) {
      final content = ns.group(1)!.trim();
      if (content.length < 500) {
        print('    $content');
      } else {
        print('    ${content.length} chars');
      }
    }
    
    // Check for JSON-LD
    final jsonLd = RegExp(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', dotAll: true)
        .allMatches(html).toList();
    print('  JSON-LD: ${jsonLd.length}');
    for (final j in jsonLd) {
      print('    ${j.group(1)?.substring(0, 200.clamp(0, j.group(1)!.length))}');
    }
  } catch (e) {
    print('  ERROR: $e');
  }

  // ── DDG Lite: GPU architecture from snippets ──
  print('\n=== DDG Lite: GPU architecture extraction ===');
  for (final q in ['NVIDIA RTX 4090', 'AMD RX 7900 XTX', 'Intel Arc A770']) {
    print('\n--- $q ---');
    try {
      final resp = await http.post(
        Uri.parse('https://lite.duckduckgo.com/lite/'),
        headers: {'User-Agent': _ua, 'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'q=${Uri.encodeComponent("$q architecture specifications")}&kl=us-en',
      ).timeout(const Duration(seconds: 10));
      print('  status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        // Extract snippets
        final snippets = RegExp(r"class='result-snippet'[^>]*>(.*?)</", dotAll: true)
            .allMatches(resp.body).take(3);
        for (final s in snippets) {
          var text = s.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
          if (text.length > 200) text = text.substring(0, 200);
          print('    snippet: $text');
        }
      }
    } catch (e) {
      print('  ERROR: $e');
    }
    await Future.delayed(const Duration(seconds: 2)); // Rate limit delay
  }
}
