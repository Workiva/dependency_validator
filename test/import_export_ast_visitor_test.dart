// Copyright 2017 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@TestOn('vm')
import 'dart:io';

import 'package:dependency_validator/src/import_export_ast_visitor.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('getDartPackageUsage', () {
    Future<DartPackageUsage> parse(String content) async {
      await d.file('test.dart', content).create();
      return getDartPackageUsage(File('${d.sandbox}/test.dart'));
    }

    test('collects top-level import and export directives', () async {
      final usage = await parse('''
import 'package:foo/foo.dart';
export 'package:bar/bar.dart';
''');
      expect(usage.directivePackageNames, {'foo', 'bar'});
      expect(usage.docImportPackageNames, isEmpty);
    });

    test('ignores part directives', () async {
      final usage = await parse('''
import 'package:foo/foo.dart';
part 'bar.dart';
''');
      expect(usage.directivePackageNames, {'foo'});
      expect(usage.docImportPackageNames, isEmpty);
    });

    test(
      'collects doc imports from documentation comments on directives',
      () async {
        final usage = await parse('''
/// @docImport 'package:yaml/yaml.dart';
import 'package:foo/foo.dart';
''');
        expect(usage.directivePackageNames, {'foo'});
        expect(usage.docImportPackageNames, {'yaml'});
      },
    );

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
