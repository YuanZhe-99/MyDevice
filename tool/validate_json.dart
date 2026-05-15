import 'dart:convert';
import 'dart:io';

/// Purpose: Initialize startup services and launch the app entry point.
/// Inputs: None.
/// Returns: None.
/// Side effects: Performs local file-system I/O.
/// Notes: Primarily intended for local validation or one-off tooling.
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
