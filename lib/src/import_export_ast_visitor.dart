import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:pub_semver/pub_semver.dart';

/// Package names referenced in a Dart file via import/export directives and
/// doc imports.
class DartPackageUsage {
  /// Package names from `import` and `export` directives.
  final Set<String> directivePackageNames;

  /// Package names from `@docImport` documentation imports.
  final Set<String> docImportPackageNames;

  const DartPackageUsage({
    required this.directivePackageNames,
    required this.docImportPackageNames,
  });
}

/// Returns the package names referenced in the provided Dart file.
DartPackageUsage getDartPackageUsage(File file) {
  ParseStringResult parsed;
  try {
    parsed = parseString(
      content: file.readAsStringSync(),
      path: file.path,
      featureSet: FeatureSet.fromEnableFlags2(
        sdkLanguageVersion: Version.parse('3.8.0'),
        flags: const [],
      ),
    );
  } on ArgumentError catch (e) {
    print('Error parsing: ${file.path}');
    print(e.message);
    exit(1);
  }

  final visitor = ImportExportVisitor();
  parsed.unit.accept(visitor);
  return DartPackageUsage(
    directivePackageNames: visitor.directivePackageNames,
    docImportPackageNames: visitor.docImportPackageNames,
  );
}

class ImportExportVisitor extends GeneralizingAstVisitor {
  Set<String> directivePackageNames = {};
  Set<String> docImportPackageNames = {};

  @override
  void visitDirective(Directive node) {
    if (node is UriBasedDirective) {
      _addPackageName(node.uri.stringValue, directivePackageNames);
    }
    super.visitDirective(node);
  }

  @override
  void visitComment(Comment node) {
    for (final docImport in node.docImports) {
      _addPackageName(docImport.import.uri.stringValue, docImportPackageNames);
    }
    super.visitComment(node);
  }

  void _addPackageName(String? uri, Set<String> packageNames) {
    if (uri == null) return;

    // ignore relative path imports
    if (!uri.startsWith('package:')) return;

    final packageParts = uri.substring('package:'.length).split('/');
    if (packageParts.isEmpty) return;

    packageNames.add(packageParts.first);
  }
}
