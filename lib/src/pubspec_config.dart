import 'package:checked_yaml/checked_yaml.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pubspec_config.g.dart';

@JsonSerializable(
  anyMap: true,
  checked: true,
  createToJson: false,
  fieldRename: FieldRename.snake,
)
class PubspecDepValidatorConfig {
  final DepValidatorConfig dependencyValidator;

  bool get isNotEmpty =>
      dependencyValidator.exclude.isNotEmpty ||
      dependencyValidator.ignore.isNotEmpty;

  PubspecDepValidatorConfig({DepValidatorConfig? dependencyValidator})
      : dependencyValidator = dependencyValidator ?? DepValidatorConfig();

  factory PubspecDepValidatorConfig.fromJson(Map json) =>
      _$PubspecDepValidatorConfigFromJson(json);

  factory PubspecDepValidatorConfig.fromYaml(String yamlContent, {sourceUrl}) =>
      checkedYamlDecode(
        yamlContent,
        (m) => PubspecDepValidatorConfig.fromJson(m ?? {}),
        allowNull: true,
        sourceUrl: sourceUrl,
      );
}

@JsonSerializable(
  anyMap: true,
  checked: true,
  createToJson: true,
  fieldRename: FieldRename.snake,
)
class DepValidatorConfig {
  @JsonKey(defaultValue: [])
  final List<String> exclude;

  @JsonKey(defaultValue: [])
  final List<String> ignore;

  @JsonKey(defaultValue: [])
  final List<String> workspaceGlobalIgnore;

  @JsonKey(defaultValue: [])
  final List<String> workspacePackageIgnore;

  @JsonKey(defaultValue: false)
  final bool allowPins;

  const DepValidatorConfig({
    this.exclude = const [],
    this.ignore = const [],
    this.workspaceGlobalIgnore = const [],
    this.workspacePackageIgnore = const [],
    this.allowPins = false,
  });

  factory DepValidatorConfig.fromJson(Map json) =>
      _$DepValidatorConfigFromJson(json);

  factory DepValidatorConfig.fromYaml(String yamlContent, {sourceUrl}) =>
      checkedYamlDecode(
        yamlContent,
        (m) => DepValidatorConfig.fromJson(m ?? {}),
        allowNull: true,
        sourceUrl: sourceUrl,
      );

  Map<String, dynamic> toJson() => _$DepValidatorConfigToJson(this);
}
