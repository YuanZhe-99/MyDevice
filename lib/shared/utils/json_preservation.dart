import 'dart:convert';

Map<String, dynamic> unknownJsonFields(
  Map<String, dynamic> json,
  Set<String> knownKeys,
) => {
  for (final entry in json.entries)
    if (!knownKeys.contains(entry.key)) entry.key: entry.value,
};

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

bool jsonValueEquals(Object? a, Object? b) =>
    jsonEncode(_canonicalJson(a)) == jsonEncode(_canonicalJson(b));

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
