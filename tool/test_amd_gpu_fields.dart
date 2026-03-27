import 'dart:convert';
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/// Quick check: what fields does AMD GPU actually have?
Future<void> main() async {
  print('=== AMD RX 7900 XTX: All DT/DD keys ===');
  await dumpAmdKeys('https://www.amd.com/en/products/graphics/desktops/radeon/7000-series/amd-radeon-rx-7900xtx.html');

  print('\n=== AMD RX 9070 XT: All DT/DD keys ===');
  await dumpAmdKeys('https://www.amd.com/en/products/graphics/desktops/radeon/9000-series/amd-radeon-rx-9070xt.html');
}

Future<void> dumpAmdKeys(String url) async {
  final resp = await http.get(Uri.parse(url),
    headers: {'User-Agent': ua, 'Accept': 'text/html'},
  ).timeout(const Duration(seconds: 20));
  if (resp.statusCode != 200) { print('  Status: ${resp.statusCode}'); return; }
  final html = utf8.decode(resp.bodyBytes, allowMalformed: true);

  for (final m in RegExp(r'<dt[^>]*>(.*?)</dt>\s*<dd[^>]*>(.*?)</dd>', dotAll: true).allMatches(html)) {
    var key = m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final val = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (key.isEmpty || val.isEmpty) continue;
    // Truncate tooltip text
    for (final marker in [' Max boost ', ' Represents ', ' Boost Clock Frequency ', " 'Game Frequency'", ' AMD`s', ' EPYC-', ' All-core', ' Recommended']) {
      final idx = key.indexOf(marker);
      if (idx > 0) { key = key.substring(0, idx); break; }
    }
    print('  $key = $val');
  }
}
