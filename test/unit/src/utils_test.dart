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
  group('importExportDartPackageRegex matches correctly for', () {
    void sharedTest(String input, String expectedGroup1, String expectedGroup2) {
      expect(input, matches(importExportDartPackageRegex));
      expect(importExportDartPackageRegex.firstMatch(input).groups([1, 2]), [expectedGroup1, expectedGroup2]);
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

          expect(input, matches(importExportDartPackageRegex));

          final allMatches = importExportDartPackageRegex.allMatches(input).toList();
          expect(allMatches, hasLength(2));

          expect(allMatches[0].groups([1, 2]), [importOrExport, 'foo']);
          expect(allMatches[1].groups([1, 2]), [importOrExport, 'bar']);
        });
      });
    }
  });

  group('importScssPackageRegex', () {
    void sharedTest(String input, String expectedGroup) {
      expect(input, matches(importScssPackageRegex));
      expect(importScssPackageRegex.firstMatch(input).group(1), expectedGroup);
    }

    test('with double-quotes', () {
      sharedTest('@import "package:foo/bar";', 'foo');
    });

    test('with single-quotes', () {
      sharedTest('@import \'package:foo/bar\';', 'foo');
    });

    test('with triple double-quotes', () {
      sharedTest('@import """package:foo/bar""";', 'foo');
    });

    test('with triple single-quotes', () {
      sharedTest('@import \'\'\'package:foo/bar\'\'\';', 'foo');
    });

    group('with a package name that', () {
      test('contains underscores', () {
        sharedTest('@import "package:foo_foo/bar";', 'foo_foo');
      });

      test('contains numbers', () {
        sharedTest('@import "package:foo1/bar";', 'foo1');
      });

      test('starts with an underscore', () {
        sharedTest('@import "package:_foo/bar";', '_foo');
      });
    });

    test('with extra whitespace in the line', () {
      sharedTest('   @import   "package:foo/bar"   ;   ', 'foo');
    });

    test('with multiple import\'s in the same line', () {
      final input = '@import "package:foo/bar"; @import "package:bar/foo";';

      expect(input, matches(importScssPackageRegex));

      final allMatches = importScssPackageRegex.allMatches(input).toList();
      expect(allMatches, hasLength(2));

      expect(allMatches[0].group(1), 'foo');
      expect(allMatches[1].group(1), 'bar');
    });
  });

  group('doesVersionPinDependency', () {
    group('with carat notation', () {
      test('is true for ^0.0.1', () {
        expect(doesVersionPinDependency('^0.0.1'), isTrue);
        expect(doesVersionPinDependency('"^0.0.19"'), isTrue);
        expect(doesVersionPinDependency("'^0.0.36'"), isTrue);
      });

      test('is false for ^0.1.2', () {
        expect(doesVersionPinDependency('^0.2.4'), isFalse);
        expect(doesVersionPinDependency('"^0.23.456"'), isFalse);
        expect(doesVersionPinDependency("'^0.23.456'"), isFalse);
      });

      test('is false for ^1.2.3', () {
        expect(doesVersionPinDependency('^1.2.4'), isFalse);
        expect(doesVersionPinDependency('"^1.23.456"'), isFalse);
        expect(doesVersionPinDependency("'^1.23.456'"), isFalse);
      });
    });

    test('is true for 1.2.3', () {
      expect(doesVersionPinDependency('1.23.456'), isTrue);
      expect(doesVersionPinDependency('"1.23.456"'), isTrue);
      expect(doesVersionPinDependency("'1.23.456'"), isTrue);
    });

    test('is true for explicit upper bound <=', () {
      expect(doesVersionPinDependency('">=1.2.3 <=4.0.0"'), isTrue);
      expect(doesVersionPinDependency("'>=1.2.3 <=4.0.0'"), isTrue);
      expect(doesVersionPinDependency('"<=4.0.0"'), isTrue);
      expect(doesVersionPinDependency("'<=4.0.0'"), isTrue);
    });

    group('is true if upper bound blocks patch or minor updates', () {
      test('when version starts with 0', () {
        expect(doesVersionPinDependency('">=0.2.3 <0.5.6"'), isTrue);
        expect(doesVersionPinDependency("'>=0.2.3 <0.5.6'"), isTrue);
        expect(doesVersionPinDependency('"<0.5.6"'), isTrue);
        expect(doesVersionPinDependency("'<0.5.6'"), isTrue);
      });

      test('when version starts with nonzero', () {
        // blocks minor updates
        expect(doesVersionPinDependency('">=1.2.3 <4.5.0"'), isTrue);
        expect(doesVersionPinDependency("'>=1.2.3 <4.5.0'"), isTrue);
        expect(doesVersionPinDependency('"<4.5.0"'), isTrue);
        expect(doesVersionPinDependency("'<4.5.0'"), isTrue);

        // blocks patch updates
        expect(doesVersionPinDependency('">=1.2.3 <4.0.6"'), isTrue);
        expect(doesVersionPinDependency("'>=1.2.3 <4.0.6'"), isTrue);
        expect(doesVersionPinDependency('"<4.0.6"'), isTrue);
        expect(doesVersionPinDependency("'<4.0.6'"), isTrue);
      });
    });

    test('is true if upper bound does not allow patch or minor updates', () {
      expect(doesVersionPinDependency('">=1.2.3 <4.5.6"'), isTrue);
      expect(doesVersionPinDependency("'>=1.2.3 <4.5.6'"), isTrue);
      expect(doesVersionPinDependency('"<4.5.6"'), isTrue);
      expect(doesVersionPinDependency("'<4.5.6'"), isTrue);
    });

    test('is true of the maximum version is 0.0.X', () {
      expect(doesVersionPinDependency('">=0.0.1 <0.0.2"'), isTrue);
      expect(doesVersionPinDependency("'>=0.0.1 <0.0.2'"), isTrue);
      expect(doesVersionPinDependency('"<0.0.2"'), isTrue);
      expect(doesVersionPinDependency("'<0.0.2'"), isTrue);
    });

    test('is true when the maximum bound contains metadata', () {
      print('start');
      expect(doesVersionPinDependency('">=0.2.0 <0.3.0-alpha"'), isTrue);
      expect(doesVersionPinDependency("'>=0.2.3 <0.3.0-alpha'"), isTrue);
      expect(doesVersionPinDependency('"<0.2.0-alpha"'), isTrue);
      expect(doesVersionPinDependency("'<0.2.0-alpha'"), isTrue);

      expect(doesVersionPinDependency('">=1.0.0 <2.0.0-alpha"'), isTrue);
      expect(doesVersionPinDependency("'>=1.2.3 <2.0.0-alpha'"), isTrue);
      expect(doesVersionPinDependency('"<2.0.0-alpha"'), isTrue);
      expect(doesVersionPinDependency("'<2.0.0-alpha'"), isTrue);
      print('end');
    });

    group('is false when the maximum version is', () {
      test('<X.0.0', () {
        expect(doesVersionPinDependency('">=1.0.0 <2.0.0"'), isFalse);
        expect(doesVersionPinDependency("'>=1.2.3 <2.0.0'"), isFalse);
        expect(doesVersionPinDependency('"<2.0.0"'), isFalse);
        expect(doesVersionPinDependency("'<2.0.0'"), isFalse);
      });

      test('<0.X.0', () {
        expect(doesVersionPinDependency('">=0.2.0 <0.3.0"'), isFalse);
        expect(doesVersionPinDependency("'>=0.2.3 <0.3.0'"), isFalse);
        expect(doesVersionPinDependency('"<0.2.0"'), isFalse);
        expect(doesVersionPinDependency("'<0.2.0'"), isFalse);
      });
    });
  });
}
