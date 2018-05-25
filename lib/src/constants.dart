/// Regex used to detect all Dart import and export directives.
final RegExp importExportDartPackageRegex =
    new RegExp(r'''\b(import|export)\s+['"]{1,3}package:([a-zA-Z0-9_]+)\/[^;]+''', multiLine: true);

/// Regex used to detect all Sass import directives.
final RegExp importScssPackageRegex = new RegExp(r'''\@import\s+['"]{1,3}package:\s*([a-zA-Z0-9_]+)\/[^;]+''');

/// String key in pubspec.yaml for the dependencies map.
const String dependenciesKey = 'dependencies';

/// Name of this package.
const String dependencyValidatorPackageName = 'dependency_validator';

/// String key in pubspec.yaml for the dev_dependencies map.
const String devDependenciesKey = 'dev_dependencies';

/// String key in pubspec.yaml for the package name.
const String nameKey = 'name';

/// String key in pubspec.yaml for the transformers map.
const String transformersKey = 'transformers';

/// Provides a set of reasons why version strings might be pins.
class DependencyPinEvaluation {
  /// The justification for why this is a pin.
  final String message;

  /// Whether this is a pin.
  final bool isPin;

  const DependencyPinEvaluation._(this.message, {this.isPin: true});

  @override
  String toString() => message;

  /// <1.2.0
  static const DependencyPinEvaluation blocksMinorBumps =
      const DependencyPinEvaluation._('This pin blocks minor bumps.');

  /// <1.2.3
  static const DependencyPinEvaluation blocksPatchReleases =
      const DependencyPinEvaluation._('This pin blocks patch upgrades.');

  /// <1.0.0+a or <1.0.0-a
  ///
  /// Note that <1.0.0-0 is legal because the exclusive bounds ignore the first
  /// possible prerelease.
  static const DependencyPinEvaluation buildOrPrerelease =
      const DependencyPinEvaluation._('Builds or preleases as max bounds block minor bumps and patches.');

  /// 1.2.3
  static const DependencyPinEvaluation directPin = const DependencyPinEvaluation._('This is a direct pin.');

  /// >1.2.3 <1.2.3
  static const DependencyPinEvaluation emptyPin =
      const DependencyPinEvaluation._('Empty dependency versions cannot be resolved.');

  /// <=1.2.3
  static const DependencyPinEvaluation inclusiveMax =
      const DependencyPinEvaluation._('Inclusive max bounds restrict minor bumps and patches.');

  /// :)
  static const DependencyPinEvaluation notAPin =
      const DependencyPinEvaluation._('This dependency is good to go.', isPin: false);
}
