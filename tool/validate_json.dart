// Validator for the bundled preset assets.
//
// Run with:  dart run tool/validate_json.dart
//
// This checks more than "does it parse". The preset files are loaded through
// `rootBundle` at runtime with casts that throw on a missing or wrong-typed
// field, so a malformed entry is a crash in the app, not a warning. Catching
// that here is the whole point.
//
// Exit code 0 when everything passes, 1 otherwise.

import 'dart:convert';
import 'dart:io';

/// Device categories accepted by `DeviceCategory.fromJson`.
///
/// Kept in step with `lib/features/devices/models/device.dart` by the
/// `preset templates` test, which asserts every template category parses.
/// Note that an unknown category does NOT throw at runtime — it silently
/// degrades to `other` — so only this check catches a typo.
const _categories = {
  'desktop',
  'laptop',
  'phone',
  'tablet',
  'headphone',
  'watch',
  'router',
  'gameConsole',
  'vps',
  'devBoard',
  'other',
};

final _errors = <String>[];

/// Purpose: Record a validation failure against a specific file and entry.
/// Inputs: `file`, `where` (entry name or index), and the `message`.
/// Returns: None.
/// Side effects: Appends to the module-level `_errors` list.
/// Notes: Primarily intended for local validation or one-off tooling.
void _fail(String file, String where, String message) {
  _errors.add('$file [$where]: $message');
}

/// Purpose: Parse one preset asset, reporting a syntax error rather than throwing.
/// Inputs: `path` — the asset path.
/// Returns: The decoded JSON, or null when the file is missing or malformed.
/// Side effects: Reads the file; may record an error.
/// Notes: Primarily intended for local validation or one-off tooling.
dynamic _load(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    _fail(path, 'file', 'does not exist');
    return null;
  }
  try {
    return jsonDecode(file.readAsStringSync());
  } catch (e) {
    _fail(path, 'syntax', '$e');
    return null;
  }
}

/// Purpose: Validate a wrapper-object preset file such as cpus/gpus/brands.
/// Inputs: `path`, the wrapper `key`, and the `requiredFields` per entry.
/// Returns: None.
/// Side effects: Reads the file; may record errors.
/// Notes: These three files wrap their array in an object, unlike
/// `device_templates.json`, which is a bare array. Primarily intended for
/// local validation or one-off tooling.
void _validateWrapped(String path, String key, List<String> requiredFields) {
  final json = _load(path);
  if (json == null) return;
  if (json is! Map<String, dynamic>) {
    _fail(path, 'root', 'expected an object with a "$key" array');
    return;
  }
  final list = json[key];
  if (list is! List) {
    _fail(path, 'root', 'missing "$key" array');
    return;
  }

  final seen = <String>{};
  for (var i = 0; i < list.length; i++) {
    final entry = list[i];
    if (entry is! Map<String, dynamic>) {
      _fail(path, '#$i', 'entry is not an object');
      continue;
    }
    for (final field in requiredFields) {
      if (entry[field] is! String || (entry[field] as String).isEmpty) {
        _fail(path, '#$i', 'missing or empty "$field"');
      }
    }
    final name = entry['name'] ?? entry['model'];
    if (name is String && !seen.add(name.toLowerCase())) {
      _fail(path, name, 'duplicate entry');
    }
  }
  stdout.writeln('$path: ${list.length} entries');
}

/// Purpose: Validate `device_templates.json` field-by-field.
/// Inputs: None.
/// Returns: None.
/// Side effects: Reads the file; may record errors.
/// Notes: Also checks the two invariants the file is maintained under — sorted
/// by lowercased name, and no duplicate names — because `tool/sort_templates.dart`
/// has to be re-run after appending entries and previously was not.
/// Primarily intended for local validation or one-off tooling.
void _validateTemplates() {
  const path = 'assets/presets/device_templates.json';
  final json = _load(path);
  if (json == null) return;
  if (json is! List) {
    _fail(path, 'root', 'expected a bare array');
    return;
  }

  final names = <String>[];
  for (var i = 0; i < json.length; i++) {
    final entry = json[i];
    if (entry is! Map<String, dynamic>) {
      _fail(path, '#$i', 'entry is not an object');
      continue;
    }

    final name = entry['name'];
    final where = name is String ? name : '#$i';
    if (name is! String || name.isEmpty) {
      _fail(path, where, 'missing or empty "name"');
    } else {
      names.add(name);
    }

    final category = entry['category'];
    if (category is! String) {
      _fail(path, where, 'missing "category"');
    } else if (!_categories.contains(category)) {
      // An unknown category degrades silently to `other` at runtime, so this
      // check is the only thing standing between a typo and a wrong icon.
      _fail(path, where, 'unknown category "$category"');
    }

    for (final field in ['brand', 'model', 'ram', 'os', 'battery', 'screenSize']) {
      if (entry.containsKey(field) && entry[field] is! String) {
        _fail(path, where, '"$field" must be a string');
      }
    }

    for (final field in ['screenResolutionW', 'screenResolutionH']) {
      if (entry.containsKey(field) && entry[field] is! int) {
        _fail(path, where, '"$field" must be an integer');
      }
    }

    final cpu = entry['cpu'];
    if (cpu != null && cpu is! String && cpu is! Map) {
      _fail(path, where, '"cpu" must be a string or an object');
    }
    if (cpu is Map && cpu['model'] is! String) {
      _fail(path, where, 'object-form "cpu" needs a "model"');
    }

    final gpu = entry['gpu'];
    if (gpu != null && gpu is! String && gpu is! Map) {
      _fail(path, where, '"gpu" must be a string or an object');
    }

    final storage = entry['storage'];
    if (storage != null) {
      if (storage is! List) {
        _fail(path, where, '"storage" must be an array');
      } else {
        for (final s in storage) {
          if (s is String) continue;
          if (s is Map && s['capacity'] is String) continue;
          _fail(path, where, 'storage entry must be a string or have "capacity"');
        }
      }
    }

    final released = entry['releaseDate'];
    if (released != null) {
      if (released is! String || DateTime.tryParse(released) == null) {
        _fail(path, where, '"releaseDate" must be an ISO-8601 date string');
      }
    }
  }

  final seen = <String>{};
  for (final name in names) {
    if (!seen.add(name.toLowerCase())) {
      _fail(path, name, 'duplicate template name');
    }
  }

  final sorted = [...names]
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  if (!_listEquals(names, sorted)) {
    final firstBad = _firstDivergence(names, sorted);
    _fail(
      path,
      'order',
      'entries are not sorted by lowercased name; first out-of-order entry is '
          '"$firstBad". Run: dart run tool/sort_templates.dart',
    );
  }

  stdout.writeln('$path: ${json.length} entries');
}

/// Purpose: Compare two string lists element-wise.
/// Inputs: `a`, `b`.
/// Returns: `true` when both have the same elements in the same order.
/// Side effects: None.
/// Notes: Primarily intended for local validation or one-off tooling.
bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Purpose: Name the first entry that is out of sorted order.
/// Inputs: `actual`, `sorted`.
/// Returns: The offending name, or an empty string.
/// Side effects: None.
/// Notes: Primarily intended for local validation or one-off tooling.
String _firstDivergence(List<String> actual, List<String> sorted) {
  for (var i = 0; i < actual.length && i < sorted.length; i++) {
    if (actual[i] != sorted[i]) return actual[i];
  }
  return '';
}

/// Purpose: Validate every bundled preset asset and report the result.
/// Inputs: None.
/// Returns: None.
/// Side effects: Reads the asset files; writes to stdout; sets `exitCode`.
/// Notes: Primarily intended for local validation or one-off tooling.
void main() {
  _validateWrapped('assets/presets/cpus.json', 'cpus', ['model']);
  _validateWrapped('assets/presets/gpus.json', 'gpus', ['model']);
  // brands.json was previously not validated at all, which is how a duplicate
  // entry survived in it.
  _validateWrapped('assets/presets/brands.json', 'brands', ['name']);
  _validateTemplates();

  stdout.writeln();
  if (_errors.isEmpty) {
    stdout.writeln('All preset assets OK.');
  } else {
    stdout.writeln('${_errors.length} problem(s):');
    for (final error in _errors) {
      stdout.writeln('  $error');
    }
    exitCode = 1;
  }
}
