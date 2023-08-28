import 'package:yaml/yaml.dart';

class PubspecDepValidatorConfig {
  final DepValidatorConfig dependencyValidator;

  bool get isNotEmpty =>
      dependencyValidator.exclude.isNotEmpty ||
      dependencyValidator.ignore.isNotEmpty;

  PubspecDepValidatorConfig({DepValidatorConfig? dependencyValidator})
      : dependencyValidator = dependencyValidator ?? DepValidatorConfig();

  factory PubspecDepValidatorConfig.fromJson(Map json) {
    var cfgMap = (json['dependency_validator'] ?? {}) as Map;
    var dependencyValidator = DepValidatorConfig.fromJson(cfgMap);
    return PubspecDepValidatorConfig(dependencyValidator: dependencyValidator);
  }

  factory PubspecDepValidatorConfig.fromYaml(String yamlContent, {sourceUrl}) =>
      PubspecDepValidatorConfig.fromJson(loadYaml(yamlContent, sourceUrl: sourceUrl) ?? {});
}

class DepValidatorConfig {
  final List<String> exclude;
  final List<String> ignore;
  final bool allowPins;

  const DepValidatorConfig({
    this.exclude = const [],
    this.ignore = const [],
    this.allowPins = false,
  });

  factory DepValidatorConfig.fromJson(Map json) =>
      DepValidatorConfig(
        exclude: _toListOfString(json['exclude']),
        ignore: _toListOfString(json['ignore']),
        allowPins: (json['allow_pins'] as bool?) ?? false,
      );

  factory DepValidatorConfig.fromYaml(String yamlContent, {sourceUrl}) =>
      DepValidatorConfig.fromJson(loadYaml(yamlContent, sourceUrl: sourceUrl) ?? {});
}

List<String> _toListOfString(dynamic v) =>
  (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [];