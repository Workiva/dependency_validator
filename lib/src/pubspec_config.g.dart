// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pubspec_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PubspecDepValidatorConfig _$PubspecDepValidatorConfigFromJson(Map json) =>
    $checkedCreate(
      'PubspecDepValidatorConfig',
      json,
      ($checkedConvert) {
        final val = PubspecDepValidatorConfig(
          dependencyValidator: $checkedConvert('dependency_validator',
              (v) => v == null ? null : DepValidatorConfig.fromJson(v as Map)),
        );
        return val;
      },
      fieldKeyMap: const {'dependencyValidator': 'dependency_validator'},
    );

DepValidatorConfig _$DepValidatorConfigFromJson(Map json) => $checkedCreate(
      'DepValidatorConfig',
      json,
      ($checkedConvert) {
        final val = DepValidatorConfig(
          exclude: $checkedConvert(
              'exclude',
              (v) =>
                  (v as List<dynamic>?)?.map((e) => e as String).toList() ??
                  []),
          ignore: $checkedConvert(
              'ignore',
              (v) =>
                  (v as List<dynamic>?)?.map((e) => e as String).toList() ??
                  []),
          allowPins: $checkedConvert('allow_pins', (v) => v as bool? ?? false),
        );
        return val;
      },
      fieldKeyMap: const {'allowPins': 'allow_pins'},
    );
