// Re-sorts assets/presets/device_templates.json by lowercased name.
//
// Run with:  dart run tool/sort_templates.dart
//
// The file is maintained in sorted order so entries are easy to find and diffs
// stay small. Appending an entry breaks that order, so run this afterwards.
// `tool/validate_json.dart` fails when the order has drifted, which is how the
// previous drift (about 33 entries appended without re-sorting) was found.

import 'dart:convert';
import 'dart:io';

/// Purpose: Sort the bundled device templates in place and rewrite the file.
/// Inputs: None.
/// Returns: None.
/// Side effects: Reads and overwrites `assets/presets/device_templates.json`.
/// Notes: Writes with `JsonEncoder.withIndent('  ')` and a trailing newline to
/// match the repo's pretty-printed JSON convention. Primarily intended for
/// local validation or one-off tooling.
void main() {
  final file = File('assets/presets/device_templates.json');
  if (!file.existsSync()) {
    stderr.writeln('${file.path} does not exist');
    exitCode = 1;
    return;
  }

  final list = jsonDecode(file.readAsStringSync()) as List;
  list.sort(
    (a, b) => (a['name'] as String).toLowerCase().compareTo(
      (b['name'] as String).toLowerCase(),
    ),
  );

  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(list)}\n');
  stdout.writeln('Done: ${list.length} templates, sorted by lowercased name.');
}
