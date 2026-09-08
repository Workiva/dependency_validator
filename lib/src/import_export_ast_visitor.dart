import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:pub_semver/pub_semver.dart';

/// Builds the feature set matching the language version a package declares,
/// the same way the analyzer derives it from the SDK constraint.
///
/// Without this, [parseString] falls back to the newest language version the
/// analyzer knows about, which may be unreleased and reject valid code.
FeatureSet featureSetForSdkConstraint(VersionConstraint? sdkConstraint) {
  if (sdkConstraint == null) return FeatureSet.latestLanguageVersion();

  final Version? min = switch (sdkConstraint) {
    Version version => version,
    VersionRange range => range.min,
    _ => null,
  };
  if (min == null) return FeatureSet.latestLanguageVersion();

  return FeatureSet.fromEnableFlags2(
    sdkLanguageVersion: Version(min.major, min.minor, 0),
    flags: const [],
  );
}

/// Returns the list of package names that are exported and imported into the
/// provided dart file
Set<String> getDartDirectivePackageNames(File file, {FeatureSet? featureSet}) {
  ParseStringResult parsed;
  final content = file.readAsStringSync();
  try {
    parsed = parseString(
      content: content,
      path: file.path,
      featureSet: featureSet,
    );
  } on ArgumentError catch (e) {
    if (featureSet != null) {
      try {
        parsed = parseString(
          content: content,
          path: file.path,
          featureSet: FeatureSet.latestLanguageVersion(),
        );
      } on ArgumentError {
        print('Error parsing: ${file.path}');
        print(e.message);
        exit(1);
      }
    } else {
      print('Error parsing: ${file.path}');
      print(e.message);
      exit(1);
    }
  }

  final visitor = ImportExportVisitor();
  parsed.unit.visitChildren(visitor);
  return visitor.packageNames;
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
