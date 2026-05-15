import 'dart:convert';

/// Purpose: Implement the unknown json fields behavior for this file.
/// Inputs: `json`, `knownKeys`.
/// Returns: `Map<String, dynamic>`.
/// Side effects: None.
/// Notes: None.
Map<String, dynamic> unknownJsonFields(
  Map<String, dynamic> json,
  Set<String> knownKeys,
) => {
  for (final entry in json.entries)
    if (!knownKeys.contains(entry.key)) entry.key: entry.value,
};

/// Purpose: Implement the merge unknown json fields behavior for this file.
/// Inputs: None.
/// Returns: `Map<String, dynamic>`.
/// Side effects: None.
/// Notes: None.
Map<String, dynamic> mergeUnknownJsonFields({
  required Map<String, dynamic> primary,
  required Map<String, dynamic> secondary,
  Map<String, dynamic>? base,
}) {
  final result = <String, dynamic>{...primary};
  final keys = {...primary.keys, ...secondary.keys, ...?base?.keys};

  for (final key in keys) {
    final primaryHas = primary.containsKey(key);
    final secondaryHas = secondary.containsKey(key);
    final baseHas = base?.containsKey(key) ?? false;

    if (primaryHas && secondaryHas) {
      if (baseHas) {
        final baseValue = base![key];
        final primaryChanged = !jsonValueEquals(primary[key], baseValue);
        final secondaryChanged = !jsonValueEquals(secondary[key], baseValue);
        if (!primaryChanged && secondaryChanged) {
          result[key] = secondary[key];
        } else {
          result[key] = primary[key];
        }
      } else {
        result[key] = primary[key];
      }
    } else if (primaryHas) {
      result[key] = primary[key];
    } else if (secondaryHas) {
      result[key] = secondary[key];
    } else {
      result.remove(key);
    }
  }

  return result;
}

/// Purpose: Return the serialized enum value used in JSON data.
/// Inputs: `a`, `b`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: None.
bool jsonValueEquals(Object? a, Object? b) =>
    jsonEncode(_canonicalJson(a)) == jsonEncode(_canonicalJson(b));

/// Purpose: Provide the internal canonical json helper for this file.
/// Inputs: `value`.
/// Returns: `Object?`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Object? _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final key in keys) key: _canonicalJson(value[key])};
  }
  if (value is List) {
    return value.map(_canonicalJson).toList();
  }
  return value;
}
