import 'package:pubspec_parse/pubspec_parse.dart';

typedef Json = Map<String, dynamic>;

/// Serializes [pubspec] for test sandbox `pubspec.yaml` files.
///
/// [Pubspec.toJson] from `pubspec_parse` includes null fields that `pub`
/// rejects, so this helper omits null and empty entries.
Json pubspecToJson(Pubspec pubspec) => _omitNullAndEmpty(pubspec.toJson());

Json _omitNullAndEmpty(Json json) {
  final result = <String, dynamic>{};
  for (final entry in json.entries) {
    final value = entry.value;
    if (value == null) continue;
    if (value is Map) {
      final nested = _omitNullAndEmpty(Map<String, dynamic>.from(value));
      if (nested.isNotEmpty) {
        result[entry.key] = nested;
      }
      continue;
    }
    if (value is List && value.isEmpty) continue;
    result[entry.key] = value;
  }
  return result;
}
