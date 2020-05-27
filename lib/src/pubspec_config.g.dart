// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pubspec_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PubspecDepValidatorConfig _$PubspecDepValidatorConfigFromJson(Map json) {
  return $checkedNew('PubspecDepValidatorConfig', json, () {
    final val = PubspecDepValidatorConfig(
      dependencyValidator: $checkedConvert(
          json, 'dependency_validator', (v) => v == null ? null : DepValidatorConfig.fromJson(v as Map)),
    );
    return val;
  }, fieldKeyMap: const {'dependencyValidator': 'dependency_validator'});
}

Map<String, dynamic> _$PubspecDepValidatorConfigToJson(PubspecDepValidatorConfig instance) => <String, dynamic>{
      'dependency_validator': instance.dependencyValidator,
    };

DepValidatorConfig _$DepValidatorConfigFromJson(Map json) {
  return $checkedNew('DepValidatorConfig', json, () {
    final val = DepValidatorConfig(
      exclude: $checkedConvert(json, 'exclude', (v) => (v as List)?.map((e) => e as String)?.toList()),
      ignore: $checkedConvert(json, 'ignore', (v) => (v as List)?.map((e) => e as String)?.toList()),
    );
    return val;
  });
}

Map<String, dynamic> _$DepValidatorConfigToJson(DepValidatorConfig instance) => <String, dynamic>{
      'exclude': instance.exclude,
      'ignore': instance.ignore,
    };
