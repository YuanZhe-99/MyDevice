import 'dart:convert';
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main() async {
  // Test 1: Verify TechPowerUp GPU og:meta pattern with multiple GPUs
  print('=== TechPowerUp GPU og:meta Pattern ===');
  final gpuUrls = {
    'RTX 4090': 'https://www.techpowerup.com/gpu-specs/geforce-rtx-4090.c3889',
    'RX 7900 XTX': 'https://www.techpowerup.com/gpu-specs/radeon-rx-7900-xtx.c3941',
    'Intel Arc A770': 'https://www.techpowerup.com/gpu-specs/arc-a770.c3914',
  };

  for (final entry in gpuUrls.entries) {
    print('\n${entry.key}:');
    try {
      final resp = await http.get(
        Uri.parse(entry.value),
        headers: {'User-Agent': ua, 'Accept': 'text/html'},
      ).timeout(const Duration(seconds: 15));
      print('  Status: ${resp.statusCode}');
      // Extract og:title
      final ogTitle = RegExp(r'<meta[^>]*property="og:title"[^>]*content="([^"]+)"')
          .firstMatch(resp.body);
      print('  og:title: ${ogTitle?.group(1)}');
      // Extract og:description
      final ogDesc = RegExp(r'<meta[^>]*property="og:description"[^>]*content="([^"]+)"')
          .firstMatch(resp.body);
      print('  og:description: ${ogDesc?.group(1)}');
      // Also try name="description" meta
      final metaDesc = RegExp(r'<meta[^>]*name="description"[^>]*content="([^"]+)"')
          .firstMatch(resp.body);
      print('  meta description: ${metaDesc?.group(1)}');
    } catch (e) {
      print('  Error: $e');
    }
    await Future.delayed(const Duration(seconds: 1));
  }

  // Test 2: Startpage → TechPowerUp GPU → og:meta for various GPUs
  print('\n\n=== Full Pipeline: Startpage → TPU GPU → og:meta ===');
  for (final q in [
    'GeForce RTX 4090',
    'Radeon RX 7900 XTX',
    'Intel Arc A770',
    'Apple M3 Max GPU',
    'Qualcomm Adreno 750',
  ]) {
    print('\nQuery: $q');
    try {
      // Step 1: Find GPU URL via Startpage
      final spResp = await http.post(
        Uri.parse('https://www.startpage.com/sp/search'),
        headers: {
          'User-Agent': ua,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'query=${Uri.encodeComponent("$q site:techpowerup.com/gpu-specs")}',
      ).timeout(const Duration(seconds: 15));

      final gpuUrl = RegExp(
        r'(https?://www\.techpowerup\.com/gpu-specs/[^\s"&<]+\.c\d+)',
      ).firstMatch(spResp.body)?.group(1);
      print('  TPU URL: $gpuUrl');

      if (gpuUrl != null) {
        await Future.delayed(const Duration(seconds: 1));
        // Step 2: Fetch GPU page for og:meta
        final resp = await http.get(
          Uri.parse(gpuUrl),
          headers: {'User-Agent': ua, 'Accept': 'text/html'},
        ).timeout(const Duration(seconds: 15));

        final ogTitle = RegExp(r'<meta[^>]*property="og:title"[^>]*content="([^"]+)"')
            .firstMatch(resp.body);
        final ogDesc = RegExp(r'<meta[^>]*property="og:description"[^>]*content="([^"]+)"')
            .firstMatch(resp.body);
        print('  og:title: ${ogTitle?.group(1)}');
        print('  og:description: ${ogDesc?.group(1)}');

        // Parse architecture from og:description
        if (ogDesc != null) {
          final desc = ogDesc.group(1)!;
          // Pattern: "VENDOR CHIP, CLOCK, CORES, TMUs, ROPs, MEMORY, MEMCLOCK, BUS"
          final parts = desc.split(', ');
          if (parts.isNotEmpty) {
            // First part is like "NVIDIA AD102" or "AMD Navi 31"
            final chipPart = parts[0];
            // Remove vendor prefix
            String chip = chipPart;
            for (final vendor in ['NVIDIA ', 'AMD ', 'Intel ', 'Apple ', 'Qualcomm ']) {
              if (chip.startsWith(vendor)) {
                chip = chip.substring(vendor.length);
                break;
              }
            }
            print('  Chip/Architecture: $chip');
          }
        }
      }
    } catch (e) {
      print('  Error: $e');
    }
    await Future.delayed(const Duration(seconds: 2));
  }

  // Test 3: Notebookcheck GPU page (using correct URL from Startpage)
  print('\n\n=== Notebookcheck GPU Detail ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.notebookcheck.net/NVIDIA-GeForce-RTX-4090-GPU-Benchmarks-and-Specs.674574.0.html'),
      headers: {
        'User-Agent': ua,
        'Accept': 'text/html',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    ).timeout(const Duration(seconds: 15));
    print('Status: ${resp.statusCode}');
    print('Body: ${resp.body.length} bytes');
    if (resp.statusCode == 200) {
      final title = RegExp(r'<title>([^<]+)').firstMatch(resp.body);
      print('Title: ${title?.group(1)}');

      // Check for spec table
      final specs = <String, String>{};
      for (final m in RegExp(
        r'<th[^>]*>([^<]+)</th>\s*<td[^>]*>(.*?)</td>',
        dotAll: true,
      ).allMatches(resp.body)) {
        final key = m.group(1)!.replaceAll(':', '').trim();
        final value = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        if (key.isNotEmpty && value.isNotEmpty) specs[key] = value;
      }
      print('TH/TD Specs: ${specs.length}');
      for (final e in specs.entries.take(20)) {
        print('  ${e.key}: ${e.value}');
      }

      // Also check for dt/dd or div-based specs
      final dtdd = RegExp(r'<dt[^>]*>(.*?)</dt>\s*<dd[^>]*>(.*?)</dd>', dotAll: true)
          .allMatches(resp.body);
      print('DT/DD pairs: ${dtdd.length}');
      for (final d in dtdd.take(10)) {
        final key = d.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        final val = d.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        print('  $key: $val');
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test 4: Check CPU og:description too (for comparison)
  print('\n\n=== TechPowerUp CPU og:meta (for comparison) ===');
  try {
    final resp = await http.get(
      Uri.parse('https://www.techpowerup.com/cpu-specs/core-i5-520m.c4365'),
      headers: {'User-Agent': ua, 'Accept': 'text/html'},
    ).timeout(const Duration(seconds: 15));
    final ogTitle = RegExp(r'<meta[^>]*property="og:title"[^>]*content="([^"]+)"')
        .firstMatch(resp.body);
    final ogDesc = RegExp(r'<meta[^>]*property="og:description"[^>]*content="([^"]+)"')
        .firstMatch(resp.body);
    print('og:title: ${ogTitle?.group(1)}');
    print('og:description: ${ogDesc?.group(1)}');
  } catch (e) {
    print('Error: $e');
  }
}
