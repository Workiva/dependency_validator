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

import 'package:test/test.dart';

import 'package:dependency_validator/src/utils.dart';

void main() {
  group('importExportPackageRegex matches correctly for', () {
    void sharedTest(String input, String expectedGroup1, String expectedGroup2) {
      expect(input, matches(importExportPackageRegex));
      expect(importExportPackageRegex.firstMatch(input).groups([1, 2]), [expectedGroup1, expectedGroup2]);
    }

    for (var importOrExport in ['import', 'export']) {
      group('an $importOrExport line', () {
        test('with double-quotes', () {
          sharedTest('$importOrExport "package:foo/bar.dart";', importOrExport, 'foo');
        });

        test('with single-quotes', () {
          sharedTest('$importOrExport \'package:foo/bar.dart\';', importOrExport, 'foo');
        });

        test('with triple double-quotes', () {
          sharedTest('$importOrExport """package:foo/bar.dart""";', importOrExport, 'foo');
        });

        test('with triple single-quotes', () {
          sharedTest('$importOrExport \'\'\'package:foo/bar.dart\'\'\';', importOrExport, 'foo');
        });

        group('with a package name that', () {
          test('contains underscores', () {
            sharedTest('$importOrExport "package:foo_foo/bar.dart";', importOrExport, 'foo_foo');
          });

          test('contains numbers', () {
            sharedTest('$importOrExport "package:foo1/bar.dart";', importOrExport, 'foo1');
          });

          test('starts with an underscore', () {
            sharedTest('$importOrExport "package:_foo/bar.dart";', importOrExport, '_foo');
          });
        });

        test('with extra whitespace in the line', () {
          sharedTest('   $importOrExport   "package:foo/bar.dart"   ;   ', importOrExport, 'foo');
        });

        test('with multiple ${importOrExport}s in the same line', () {
          final input = '$importOrExport "package:foo/bar.dart"; $importOrExport "package:bar/foo.dart";';

          expect(input, matches(importExportPackageRegex));

          final allMatches = importExportPackageRegex.allMatches(input).toList();
          expect(allMatches, hasLength(2));

          expect(allMatches[0].groups([1, 2]), [importOrExport, 'foo']);
          expect(allMatches[1].groups([1, 2]), [importOrExport, 'bar']);
        });
      });
    }
  });
}
