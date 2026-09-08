import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

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
    parsed = parseString(content: file.readAsStringSync(), path: file.path);
  } on ArgumentError catch (e) {
    print('Error parsing: ${file.path}');
    print(e.message);
    exit(1);
  }

  final visitor = ImportExportVisitor();
  parsed.unit.accept(visitor);
  _collectDocImportsFromPrecedingComments(
    parsed.unit.beginToken.precedingComments,
    visitor.docImportPackageNames,
  );
  return DartPackageUsage(
    directivePackageNames: visitor.directivePackageNames,
    docImportPackageNames: visitor.docImportPackageNames,
  );
}

void _collectDocImportsFromPrecedingComments(
  Token? commentToken,
  Set<String> docImportPackageNames,
) {
  for (var token = commentToken; token != null; token = token.next) {
    if (token is! CommentToken) continue;
    _collectDocImportsFromCommentLexeme(token.lexeme, docImportPackageNames);
  }
}

final _docImportUriPattern = RegExp(
  r'''@docImport\s+(['"])(.+?)\1''',
  multiLine: true,
);

void _collectDocImportsFromCommentLexeme(
  String lexeme,
  Set<String> docImportPackageNames,
) {
  for (final match in _docImportUriPattern.allMatches(lexeme)) {
    _addPackageName(match.group(2), docImportPackageNames);
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
}
