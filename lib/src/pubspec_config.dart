import 'package:checked_yaml/checked_yaml.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pubspec_config.g.dart';

@JsonSerializable(anyMap: true, checked: true, createToJson: false, fieldRename: FieldRename.snake)
class PubspecDepValidatorConfig {
  final DepValidatorConfig dependencyValidator;

  PubspecDepValidatorConfig({this.dependencyValidator});

  factory PubspecDepValidatorConfig.fromJson(Map json) => _$PubspecDepValidatorConfigFromJson(json);

  factory PubspecDepValidatorConfig.fromYaml(String yamlContent, {sourceUrl}) =>
      checkedYamlDecode(yamlContent, (m) => PubspecDepValidatorConfig.fromJson(m), sourceUrl: sourceUrl);
}

@JsonSerializable(anyMap: true, checked: true, createToJson: false, fieldRename: FieldRename.snake)
class DepValidatorConfig {
  final List<String> exclude;

  final List<String> ignore;

  DepValidatorConfig({this.exclude, this.ignore});

  factory DepValidatorConfig.fromJson(Map json) => _$DepValidatorConfigFromJson(json);
}
