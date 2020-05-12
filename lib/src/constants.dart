/// Regex used to detect all Dart import and export directives.
final RegExp importExportDartPackageRegex = RegExp(
    r'''\b(import|export)\s+['"]{1,3}package:([a-zA-Z0-9_]+)\/[^;]+''',
    multiLine: true);

/// Regex used to detect all Sass import directives.
final RegExp importScssPackageRegex =
    RegExp(r'''\@import\s+['"]{1,3}package:\s*([a-zA-Z0-9_]+)\/[^;]+''');

/// Regex used to detect all Less import directives.
final RegExp importLessPackageRegex = RegExp(r'@import\s+(?:\(.*\)\s+)?"(?:packages\/|package:\/\/)([a-zA-Z1-9_-]+)\/');

/// String key in pubspec.yaml for the dependencies map.
const String dependenciesKey = 'dependencies';

/// Name of this package.
const String dependencyValidatorPackageName = 'dependency_validator';

/// String key in pubspec.yaml for the dev_dependencies map.
const String devDependenciesKey = 'dev_dependencies';

/// String key in pubspec.yaml for the package name.
const String nameKey = 'name';

/// Packages that are typically only used for their binaries.
const List<String> commonBinaryPackages = [
  'build_runner',
  'build_test',
  'build_vm_compilers',
  'build_web_compilers',
  'built_value_generator',
  'coverage',
  'dart_dev',
  'dart_style',
];

/// Provides a set of reasons why version strings might be pins.
class DependencyPinEvaluation {
  const DependencyPinEvaluation._(this.message, {this.isPin = true});

  /// The justification for why this is a pin.
  final String message;

  /// Whether this is a pin.
  final bool isPin;

  @override
  String toString() => message;

  /// <1.2.0
  static const DependencyPinEvaluation blocksMinorBumps =
      DependencyPinEvaluation._('This pin blocks minor bumps.');

  /// <1.2.3
  static const DependencyPinEvaluation blocksPatchReleases =
      DependencyPinEvaluation._('This pin blocks patch upgrades.');

  /// <1.0.0+a or <1.0.0-a
  ///
  /// Note that <1.0.0-0 is legal because the exclusive bounds ignore the first
  /// possible prerelease.
  static const DependencyPinEvaluation buildOrPrerelease =
      DependencyPinEvaluation._(
          'Builds or preleases as max bounds block minor bumps and patches.');

  /// 1.2.3
  static const DependencyPinEvaluation directPin =
      DependencyPinEvaluation._('This is a direct pin.');

  /// >1.2.3 <1.2.3
  static const DependencyPinEvaluation emptyPin = DependencyPinEvaluation._(
      'Empty dependency versions cannot be resolved.');

  /// <=1.2.3
  static const DependencyPinEvaluation inclusiveMax = DependencyPinEvaluation._(
      'Inclusive max bounds restrict minor bumps and patches.');

  /// :)
  static const DependencyPinEvaluation notAPin =
      DependencyPinEvaluation._('This dependency is good to go.', isPin: false);
}
