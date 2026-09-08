import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Package names referenced by import/export directives and `@docImport`s.
class DartPackageUsage {
  /// Package names from top-level import and export directives.
  final Set<String> directivePackageNames;

  /// Package names from `@docImport` tags in documentation comments.
  final Set<String> docImportPackageNames;

  const DartPackageUsage({
    required this.directivePackageNames,
    required this.docImportPackageNames,
  });
}

/// Returns the list of package names that are exported and imported into the
/// provided dart file.
Set<String> getDartDirectivePackageNames(File file) =>
    getDartPackageUsage(file).directivePackageNames;

/// Returns package names referenced via import/export directives and doc
/// imports in the provided dart file.
DartPackageUsage getDartPackageUsage(File file) {
  ParseStringResult parsed;
  try {
    parsed = parseString(content: file.readAsStringSync(), path: file.path);
  } on ArgumentError catch (e) {
    print('Error parsing: ${file.path}');
    print(e.message);
    exit(1);
  }

  final visitor = ImportExportVisitor();
  parsed.unit.accept(visitor);
  return DartPackageUsage(
    directivePackageNames: visitor.packageNames,
    docImportPackageNames: visitor.docImportPackageNames,
  );
}

class ImportExportVisitor extends GeneralizingAstVisitor<void> {
  Set<String> packageNames = {};
  Set<String> docImportPackageNames = {};

  @override
  void visitDirective(Directive node) {
    if (node.parent is CompilationUnit && node is UriBasedDirective) {
      _addPackageName(node.uri.stringValue, packageNames);
    }
    node.visitChildren(this);
  }

  @override
  void visitComment(Comment node) {
    for (final docImport in node.docImports) {
      _addPackageName(docImport.import.uri.stringValue, docImportPackageNames);
    }
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
