import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import 'utils.dart';

/// Returns the list of package names that are exported and imported into the
/// provided dart file, which is parsed with the given [featureSet].
///
/// See [featureSetForPubspec] for resolving the [featureSet] of the package
/// that [file] belongs to.
Set<String> getDartDirectivePackageNames(
  File file, {
  required FeatureSet featureSet,
}) {
  ParseStringResult parsed;
  try {
    parsed = parseString(
      content: file.readAsStringSync(),
      path: file.path,
      featureSet: featureSet,
    );
  } on ArgumentError catch (e) {
    print('Error parsing: ${file.path}');
    print(e.message);
    exit(1);
  }

  final visitor = ImportExportVisitor();
  parsed.unit.visitChildren(visitor);
  return visitor.packageNames;
}

/// Returns the [FeatureSet] that matches the Dart SDK version declared by the
/// `environment: sdk:` constraint of [pubspec].
///
/// Falls back to [FeatureSet.latestLanguageVersion] when [pubspec] does not
/// declare an SDK constraint with a lower bound.
FeatureSet featureSetForPubspec(Pubspec pubspec) {
  final languageVersion = _sdkLanguageVersionOf(pubspec);
  if (languageVersion == null) {
    logger.fine(
      'No SDK version found for ${pubspec.name}, '
      'parsing with the latest language version.',
    );
    return FeatureSet.latestLanguageVersion();
  }

  logger.fine('Using language version $languageVersion for ${pubspec.name}');
  return FeatureSet.fromEnableFlags2(
    sdkLanguageVersion: languageVersion,
    flags: const [],
  );
}

/// Returns the language version implied by the `environment: sdk:` constraint
/// of [pubspec], or null if it has none.
Version? _sdkLanguageVersionOf(Pubspec pubspec) {
  final sdkConstraint = pubspec.environment['sdk'];

  // `Version` also implements `VersionRange`, with itself as the lower bound.
  final minSdkVersion =
      sdkConstraint is VersionRange ? sdkConstraint.min : null;
  if (minSdkVersion == null) return null;

  // A language version is only major.minor.
  return Version(minSdkVersion.major, minSdkVersion.minor, 0);
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
