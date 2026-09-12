import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:pub_semver/pub_semver.dart';

/// The running SDK's language version. `parseString` otherwise defaults to the
/// analyzer's *latest* language version, which can be ahead of the SDK and reject
/// code the SDK compiles (e.g. `required final` parameters in freezed output).
final _sdkFeatureSet = FeatureSet.fromEnableFlags2(
  sdkLanguageVersion: Version.parse(Platform.version.split(' ').first),
  flags: const [],
);

/// Returns the list of package names that are exported and imported into the
/// provided dart file
Set<String> getDartDirectivePackageNames(File file) {
  ParseStringResult parsed;
  try {
    // Only directives are read below, so a syntax error deeper in the file must
    // not abort the whole run.
    parsed = parseString(
      content: file.readAsStringSync(),
      path: file.path,
      featureSet: _sdkFeatureSet,
      throwIfDiagnostics: false,
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
