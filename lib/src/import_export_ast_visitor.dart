import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Returns the list of package names that are exported and imported into the
/// provided dart file
Set<String> getDartDirectivePackageNames(File file) {
  ParseStringResult parsed;
  try {
    parsed = parseString(content: file.readAsStringSync(), path: file.path);
  } catch(e) {
    print('Error parsing: ${file.path}');
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
