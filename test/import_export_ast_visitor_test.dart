import 'dart:io';

import 'package:dependency_validator/src/import_export_ast_visitor.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('getDartPackageUsage', () {
    test('collects import and export directives', () async {
      await d.dir('project', [
        d.file('main.dart', '''
import 'package:logging/logging.dart';
export 'package:meta/meta.dart';
'''),
      ]).create();

      final usage = getDartPackageUsage(File('${d.sandbox}/project/main.dart'));

      expect(usage.directivePackageNames, {'logging', 'meta'});
      expect(usage.docImportPackageNames, isEmpty);
    });

    test('collects doc imports from documentation comments', () async {
      await d.dir('project', [
        d.file('main.dart', '''
/// @docImport 'package:meta/meta.dart';
library;

/// References [Deprecated].
class Foo {}
'''),
      ]).create();

      final usage = getDartPackageUsage(File('${d.sandbox}/project/main.dart'));

      expect(usage.directivePackageNames, isEmpty);
      expect(usage.docImportPackageNames, {'meta'});
    });

    test(
      'collects doc imports from declaration doc comments without a library directive',
      () async {
        await d.dir('project', [
          d.file('main.dart', '''
/// @docImport 'package:meta/meta.dart';
/// References [Deprecated].
class Foo {}
'''),
        ]).create();

        final usage = getDartPackageUsage(
          File('${d.sandbox}/project/main.dart'),
        );

        expect(usage.directivePackageNames, isEmpty);
        expect(usage.docImportPackageNames, {'meta'});
      },
    );

    test(
      'collects file-level dangling doc imports from beginToken.precedingComments',
      () async {
        await d.dir('project', [
          d.file('main.dart', '''
/// @docImport 'package:meta/meta.dart';
'''),
        ]).create();

        final usage = getDartPackageUsage(
          File('${d.sandbox}/project/main.dart'),
        );

        expect(usage.directivePackageNames, isEmpty);
        expect(usage.docImportPackageNames, {'meta'});
      },
    );

    test('ignores @docImport text in non-doc comments', () async {
      await d.dir('project', [
        d.file('main.dart', '''
// @docImport 'package:meta/meta.dart';
/* @docImport 'package:yaml/yaml.dart'; */
// /// @docImport 'package:logging/logging.dart';
class Foo {}
'''),
      ]).create();

      final usage = getDartPackageUsage(File('${d.sandbox}/project/main.dart'));

      expect(usage.directivePackageNames, isEmpty);
      expect(usage.docImportPackageNames, isEmpty);
    });

    test(
      'ignores @docImport inside fenced code blocks in doc comments',
      () async {
        await d.dir('project', [
          d.file('main.dart', '''
/// Example:
/// ```dart
/// /// @docImport 'package:meta/meta.dart';
/// ```
library;

/** Another example:
 * ```
 * /// @docImport 'package:yaml/yaml.dart';
 * ```
 */
class Foo {}
'''),
        ]).create();

        final usage = getDartPackageUsage(
          File('${d.sandbox}/project/main.dart'),
        );

        expect(usage.docImportPackageNames, isEmpty);
      },
    );

    test('ignores @docImport mentioned mid-line in a doc comment', () async {
      await d.dir('project', [
        d.file('main.dart', '''
/// Use `@docImport 'package:meta/meta.dart';` to reference [Deprecated].
library;
'''),
      ]).create();

      final usage = getDartPackageUsage(File('${d.sandbox}/project/main.dart'));

      expect(usage.docImportPackageNames, isEmpty);
    });

    test('collects both directives and doc imports', () async {
      await d.dir('project', [
        d.file('main.dart', '''
/// @docImport 'package:yaml/yaml.dart';
library;

import 'package:logging/logging.dart';

/// References [YamlMap].
class Foo {}
'''),
      ]).create();

      final usage = getDartPackageUsage(File('${d.sandbox}/project/main.dart'));

      expect(usage.directivePackageNames, {'logging'});
      expect(usage.docImportPackageNames, {'yaml'});
    });

    test('collects package names from doc imports with show clauses', () async {
      await d.dir('project', [
        d.file('main.dart', '''
/// @docImport 'package:collection/collection.dart' show IterableExtension;
library;

/// References [IterableExtension].
class Foo {}
'''),
      ]).create();

      final usage = getDartPackageUsage(File('${d.sandbox}/project/main.dart'));

      expect(usage.docImportPackageNames, {'collection'});
    });

    test('collects package names from doc imports with as clauses', () async {
      await d.dir('project', [
        d.file('main.dart', '''
/// @docImport 'package:collection/collection.dart' as collection;
library;

/// References [collection.IterableExtension].
class Foo {}
'''),
      ]).create();

      final usage = getDartPackageUsage(File('${d.sandbox}/project/main.dart'));

      expect(usage.docImportPackageNames, {'collection'});
    });

    test('collects doc imports from bin/ files', () async {
      await d.dir('project', [
        d.dir('bin', [
          d.file('main.dart', '''
/// @docImport 'package:meta/meta.dart';
/// References [Deprecated].
void main() {}
'''),
        ]),
      ]).create();

      final usage = getDartPackageUsage(
        File('${d.sandbox}/project/bin/main.dart'),
      );

      expect(usage.directivePackageNames, isEmpty);
      expect(usage.docImportPackageNames, {'meta'});
    });

    test('ignores relative and dart scheme imports', () async {
      await d.dir('project', [
        d.file('main.dart', '''
/// @docImport 'dart:async';
import 'other.dart';
'''),
      ]).create();

      final usage = getDartPackageUsage(File('${d.sandbox}/project/main.dart'));

      expect(usage.directivePackageNames, isEmpty);
      expect(usage.docImportPackageNames, isEmpty);
    });
  });
}
