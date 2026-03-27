import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/presets/device_templates.json');
  final list = jsonDecode(file.readAsStringSync()) as List;

  // New entries to add (empty since already added)
  final newEntries = <Map<String, dynamic>>[];

  list.addAll(newEntries);

  // Sort alphabetically by name (case-insensitive)
  list.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

  // Write back with nice formatting
  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync(encoder.convert(list) + '\n');

  print('Done: ${list.length} templates, sorted alphabetically.');
}
