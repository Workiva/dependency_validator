import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:dependency_validator/src/utils.dart';
import 'package:pub_semver/pub_semver.dart';

/// Returns the SDK language version implied by [sdkConstraint], or null when
/// the latest language version should be used.
Version? languageVersionForSdkConstraint(VersionConstraint? sdkConstraint) {
  final min = sdkConstraint is VersionRange ? sdkConstraint.min : null;
  if (min == null) return null;

  return Version(min.major, min.minor, 0);
}

/// Builds the feature set matching the language version a package declares,
/// the same way the analyzer derives it from the SDK constraint.
///
/// Without this, [parseString] falls back to the newest language version the
/// analyzer knows about, which may be unreleased and reject valid code.
FeatureSet featureSetForSdkConstraint(VersionConstraint? sdkConstraint) {
  final languageVersion = languageVersionForSdkConstraint(sdkConstraint);
  if (languageVersion == null) return FeatureSet.latestLanguageVersion();

  return FeatureSet.fromEnableFlags2(
    sdkLanguageVersion: languageVersion,
    flags: const [],
  );
}

/// Returns the list of package names that are exported and imported into the
/// provided dart file
Set<String> getDartDirectivePackageNames(
  File file, {
  VersionConstraint? sdkConstraint,
}) {
  final featureSet = featureSetForSdkConstraint(sdkConstraint);
  final derivedLanguageVersion = languageVersionForSdkConstraint(sdkConstraint);

  ParseStringResult parsed;
  final content = file.readAsStringSync();
  try {
    parsed = parseString(
      content: content,
      path: file.path,
      featureSet: featureSet,
    );
  } on ArgumentError catch (e) {
    if (derivedLanguageVersion != null) {
      try {
        parsed = parseString(
          content: content,
          path: file.path,
          featureSet: FeatureSet.latestLanguageVersion(),
        );
        logger.fine(
          'Parsed ${file.path} with latest language version after failing '
          'with derived version $derivedLanguageVersion',
        );
      } on ArgumentError catch (retryError) {
        _reportParseError(
          file,
          derivedLanguageVersion: derivedLanguageVersion,
          error: retryError,
        );
      }
    } else {
      _reportParseError(file, error: e);
    }
  }

  final visitor = ImportExportVisitor();
  parsed.unit.visitChildren(visitor);
  return visitor.packageNames;
}

Never _reportParseError(
  File file, {
  Version? derivedLanguageVersion,
  required ArgumentError error,
}) {
  print('Error parsing: ${file.path}');
  if (derivedLanguageVersion != null) {
    print('Derived language version: $derivedLanguageVersion');
  }
  print(error.message);
  exit(1);
}

class ImportExportVisitor extends GeneralizingAstVisitor {
  Set<String> packageNames = {};

  @override
  void visitDirective(Directive node) {
    if (node is! UriBasedDirective) return;

    final uri = node.uri.stringValue;
    if (uri == null) return;

    // ignore relative path imports
    if (!uri.startsWith('package:')) return;

    final packageParts = uri.substring('package:'.length).split('/');
    if (packageParts.isEmpty)
      return; // sanity check, this probably will never happen

    packageNames.add(packageParts.first);
  }
}
