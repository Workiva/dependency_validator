import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:pub_semver/pub_semver.dart';

/// Builds the feature set matching the language version a package declares,
/// the same way the analyzer derives it from the SDK constraint.
///
/// Without this, [parseString] falls back to the newest language version the
/// analyzer knows about, which may be unreleased and reject valid code.
FeatureSet featureSetForSdkConstraint(VersionConstraint? sdkConstraint) {
  final min = sdkConstraint is VersionRange ? sdkConstraint.min : null;
  if (min == null) return FeatureSet.latestLanguageVersion();

  return FeatureSet.fromEnableFlags2(
    sdkLanguageVersion: Version(min.major, min.minor, 0),
    flags: const [],
  );
}

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
DartPackageUsage getDartPackageUsage(File file, {FeatureSet? featureSet}) {
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

/// Collects `@docImport` package names from comment tokens that are not
/// attached to any AST node (e.g. a file containing only a doc comment).
///
/// Mirrors the analyzer's own doc comment parsing as closely as is practical:
/// only `///` and `/** */` doc comments are considered, `@docImport` must start
/// a line, and fenced code blocks are skipped.
void _collectDocImportsFromPrecedingComments(
  Token? commentToken,
  Set<String> docImportPackageNames,
) {
  var inFencedCodeBlock = false;
  for (var token = commentToken; token != null; token = token.next) {
    if (token is! CommentToken) continue;

    final lexeme = token.lexeme;
    final isBlockDocComment = lexeme.startsWith('/**');
    if (!isBlockDocComment && !lexeme.startsWith('///')) continue;

    // A block doc comment is self-contained; don't carry fence state into it.
    if (isBlockDocComment) inFencedCodeBlock = false;

    for (final line in lexeme.split('\n')) {
      final content = _stripDocCommentDecoration(line);
      if (content.startsWith('```')) {
        inFencedCodeBlock = !inFencedCodeBlock;
        continue;
      }
      if (inFencedCodeBlock) continue;
      _collectDocImportFromLine(content, docImportPackageNames);
    }
  }
}

/// Strips the leading `///`, `/**`, or ` * ` and trailing `*/` from a single
/// line of a doc comment lexeme.
String _stripDocCommentDecoration(String line) {
  var content = line.trim();
  if (content.startsWith('///') || content.startsWith('/**')) {
    content = content.substring(3);
  } else if (content.startsWith('*')) {
    content = content.substring(1);
  }
  if (content.endsWith('*/')) {
    content = content.substring(0, content.length - 2);
  }
  return content.trim();
}

final _docImportUriPattern = RegExp(r'''^@docImport\s+(['"])(.+?)\1''');

void _collectDocImportFromLine(String line, Set<String> docImportPackageNames) {
  final match = _docImportUriPattern.firstMatch(line);
  if (match == null) return;
  _addPackageName(match.group(2), docImportPackageNames);
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
