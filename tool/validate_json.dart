import 'dart:convert';
import 'dart:io';

void main() {
  for (final path in [
    'assets/presets/cpus.json',
    'assets/presets/gpus.json',
    'assets/presets/device_templates.json',
  ]) {
    try {
      jsonDecode(File(path).readAsStringSync());
      print('$path OK');
    } catch (e) {
      print('$path FAILED: $e');
      exitCode = 1;
    }
  }
}
