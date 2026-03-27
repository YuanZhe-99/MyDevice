// ignore_for_file: avoid_print
import 'package:http/http.dart' as http;

const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  final resp = await http.get(
    Uri.parse('https://www.techpowerup.com/gpu-specs/geforce-rtx-4090.c3889'),
    headers: {'User-Agent': _ua, 'Accept': 'text/html'},
  ).timeout(const Duration(seconds: 10));
  
  final scripts = RegExp(r'<script[^>]*>(.*?)</script>', dotAll: true)
      .allMatches(resp.body).toList();
  
  for (int i = 0; i < scripts.length; i++) {
    final content = scripts[i].group(1)!.trim();
    if (content.contains('4090')) {
      // Look for JSON object patterns near "4090"
      final matches = '4090'.allMatches(content).take(5).toList();
      for (final m in matches) {
        final start = (m.start - 300).clamp(0, content.length);
        final end = (m.start + 300).clamp(0, content.length);
        print('=== Context around "4090" at ${m.start} ===');
        print(content.substring(start, end));
        print('');
      }
      
      // Look for "Architecture" or "Ada" near "4090"
      final adaIdx = content.indexOf('Ada');
      if (adaIdx >= 0) {
        final start = (adaIdx - 200).clamp(0, content.length);
        final end = (adaIdx + 200).clamp(0, content.length);
        print('=== Context around "Ada" ===');
        print(content.substring(start, end));
      }
      
      // Look for JSON-like structure
      final jsonStart = content.indexOf('{');
      if (jsonStart >= 0 && jsonStart < 100) {
        print('=== First 500 chars of script ===');
        print(content.substring(0, 500.clamp(0, content.length)));
      }
      break;
    }
  }
}
