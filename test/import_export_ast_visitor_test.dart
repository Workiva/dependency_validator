import 'dart:io';

import 'package:dependency_validator/src/import_export_ast_visitor.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('getDartPackageUsage', () {
    Future<DartPackageUsage> parse(String content) async {
      final file = File('${d.sandbox}/test.dart');
      await d.file('test.dart', content).create();
      return getDartPackageUsage(file);
    }

    test('collects top-level import and export directives', () async {
      final usage = await parse('''
import 'package:foo/foo.dart';
export 'package:bar/bar.dart';
''');
      expect(usage.directivePackageNames, {'foo', 'bar'});
      expect(usage.docImportPackageNames, isEmpty);
    });

    test('ignores nested import directives', () async {
      final usage = await parse('''
import 'package:foo/foo.dart';

void main() {
  // Not a real import directive.
}
''');
      expect(usage.directivePackageNames, {'foo'});
      expect(usage.docImportPackageNames, isEmpty);
    });

    test('collects doc imports from library comments', () async {
      final usage = await parse('''
/// @docImport 'package:yaml/yaml.dart';
library;

class Foo {}
''');
      expect(usage.directivePackageNames, isEmpty);
      expect(usage.docImportPackageNames, {'yaml'});
    });

    test('collects doc imports from declaration comments', () async {
      final usage = await parse('''
/// @docImport 'package:yaml/yaml.dart';
class Foo {}
''');
      expect(usage.directivePackageNames, isEmpty);
      expect(usage.docImportPackageNames, {'yaml'});
    });

    test('collects multiple doc imports', () async {
      final usage = await parse('''
/// @docImport 'package:yaml/yaml.dart';
/// @docImport 'package:logging/logging.dart';
library;
''');
      expect(usage.docImportPackageNames, {'yaml', 'logging'});
    });

    test('ignores dart: and relative doc imports', () async {
      final usage = await parse('''
/// @docImport 'dart:async';
/// @docImport 'other.dart';
library;
''');
      expect(usage.docImportPackageNames, isEmpty);
    });
  });
}
