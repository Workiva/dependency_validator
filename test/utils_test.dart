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
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:dependency_validator/src/constants.dart';
import 'package:dependency_validator/src/utils.dart';

void main() {
  group('getAnalysisOptionsIncludePackage', () {
    test('no analysis_options.yaml', () {
      expect(getAnalysisOptionsIncludePackage(path: d.sandbox), isNull);
    });

    test('empty file', () async {
      await d.file('analysis_options.yaml', '').create();
      expect(getAnalysisOptionsIncludePackage(path: d.sandbox), isNull);
    });

    test('no `include:`', () async {
      await d.file('analysis_options.yaml', '''
linter:
  rules: []
''').create();
      expect(getAnalysisOptionsIncludePackage(path: d.sandbox), isNull);
    });

    test('returns package name from `include:`', () async {
      await d.file('analysis_options.yaml', '''
include: package:pedantic/analysis_options.1.8.0.yaml
''').create();
      expect(getAnalysisOptionsIncludePackage(path: d.sandbox), {'pedantic'});
    });

    test('returns package names from list `include:`', () async {
      await d.file('analysis_options.yaml', '''
include:
  - package:flutter_lints/flutter.yaml
  - package:pedantic/analysis_options.1.8.0.yaml
''').create();
      expect(getAnalysisOptionsIncludePackage(path: d.sandbox),
          {'flutter_lints', 'pedantic'});
    });

    test('filters out non-package includes from list', () async {
      await d.file('analysis_options.yaml', '''
include:
  - package:flutter_lints/flutter.yaml
  - analysis_options_shared.yaml
  - package:pedantic/analysis_options.1.8.0.yaml
''').create();
      expect(getAnalysisOptionsIncludePackage(path: d.sandbox),
          {'flutter_lints', 'pedantic'});
    });

    test('returns null for list with no package includes', () async {
      await d.file('analysis_options.yaml', '''
include:
  - analysis_options_shared.yaml
  - ../common_options.yaml
''').create();
      expect(getAnalysisOptionsIncludePackage(path: d.sandbox), isNull);
    });

    test('handles empty list', () async {
      await d.file('analysis_options.yaml', '''
include: []
''').create();
      expect(getAnalysisOptionsIncludePackage(path: d.sandbox), isNull);
    });
  });

  group('importExportDartPackageRegex matches correctly for', () {
    void sharedTest(
      String input,
      String expectedGroup1,
      String expectedGroup2,
    ) {
      expect(input, matches(importExportDartPackageRegex));
      expect(importExportDartPackageRegex.firstMatch(input)!.groups([1, 2]), [
        expectedGroup1,
        expectedGroup2,
      ]);
    }

    for (var importOrExport in ['import', 'export']) {
      group('an $importOrExport line', () {
        test('with double-quotes', () {
          sharedTest(
            '$importOrExport "package:foo/bar.dart";',
            importOrExport,
            'foo',
          );
        });

        test('with single-quotes', () {
          sharedTest(
            '$importOrExport \'package:foo/bar.dart\';',
            importOrExport,
            'foo',
          );
        });

        test('with triple double-quotes', () {
          sharedTest(
            '$importOrExport """package:foo/bar.dart""";',
            importOrExport,
            'foo',
          );
        });

        test('with triple single-quotes', () {
          sharedTest(
            '$importOrExport \'\'\'package:foo/bar.dart\'\'\';',
            importOrExport,
            'foo',
          );
        });

        group('with a package name that', () {
          test('contains underscores', () {
            sharedTest(
              '$importOrExport "package:foo_foo/bar.dart";',
              importOrExport,
              'foo_foo',
            );
          });

          test('contains numbers', () {
            sharedTest(
              '$importOrExport "package:foo1/bar.dart";',
              importOrExport,
              'foo1',
            );
          });

          test('starts with an underscore', () {
            sharedTest(
              '$importOrExport "package:_foo/bar.dart";',
              importOrExport,
              '_foo',
            );
          });
        });

        test('with extra whitespace in the line', () {
          sharedTest(
            '   $importOrExport   "package:foo/bar.dart"   ;   ',
            importOrExport,
            'foo',
          );
        });

        test('with multiple ${importOrExport}s in the same line', () {
          final input =
              '$importOrExport "package:foo/bar.dart"; $importOrExport "package:bar/foo.dart";';

          expect(input, matches(importExportDartPackageRegex));

          final allMatches =
              importExportDartPackageRegex.allMatches(input).toList();
          expect(allMatches, hasLength(2));

          expect(allMatches[0].groups([1, 2]), [importOrExport, 'foo']);
          expect(allMatches[1].groups([1, 2]), [importOrExport, 'bar']);
        });
      });
    }
  });

  group('importLessPackageRegex', () {
    void sharedTest(String input, String expectedGroup) {
      expect(input, matches(importLessPackageRegex));
      expect(importLessPackageRegex.firstMatch(input)!.group(1), expectedGroup);
    }

    test('with double-quotes', () {
      sharedTest('@import "packages/foo/bar";', 'foo');
      sharedTest('@import "package://foo/bar";', 'foo');
    });

    group('with a package name that', () {
      test('contains underscores', () {
        sharedTest('@import "packages/foo_foo/bar";', 'foo_foo');
        sharedTest('@import "package://foo_foo/bar";', 'foo_foo');
      });

      test('contains numbers', () {
        sharedTest('@import "packages/foo1/bar";', 'foo1');
        sharedTest('@import "package://foo1/bar";', 'foo1');
      });

      test('starts with an underscore', () {
        sharedTest('@import "packages/_foo/bar";', '_foo');
        sharedTest('@import "package://_foo/bar";', '_foo');
      });
    });

    test('with extra whitespace in the line', () {
      sharedTest('   @import   "packages/foo/bar"   ;   ', 'foo');
      sharedTest('   @import   "package://foo/bar"   ;   ', 'foo');
    });

    test('with multiple imports in the same line', () {
      const input = '@import "packages/foo/bar"; @import "package://bar/foo";';

      expect(input, matches(importLessPackageRegex));

      final allMatches = importLessPackageRegex.allMatches(input).toList();
      expect(allMatches, hasLength(2));

      expect(allMatches[0].group(1), 'foo');
      expect(allMatches[1].group(1), 'bar');
    });
  });

  group('importScssPackageRegex', () {
    void sharedTest(String input, String expectedGroup) {
      expect(input, matches(importScssPackageRegex));
      expect(importScssPackageRegex.firstMatch(input)!.group(1), expectedGroup);
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
      const input = '@import "package:foo/bar"; @import "package:bar/foo";';

      expect(input, matches(importScssPackageRegex));

      final allMatches = importScssPackageRegex.allMatches(input).toList();
      expect(allMatches, hasLength(2));

      expect(allMatches[0].group(1), 'foo');
      expect(allMatches[1].group(1), 'bar');
    });
  });

  group('inspectVersionForPins classifies', () {
    test('any', () {
      expect(
        inspectVersionForPins(VersionConstraint.parse('any')),
        DependencyPinEvaluation.notAPin,
      );
    });

    test('empty', () {
      expect(
        inspectVersionForPins(VersionConstraint.parse('>0.0.0 <0.0.0')),
        DependencyPinEvaluation.emptyPin,
      );
    });

    test('caret notation', () {
      expect(
        inspectVersionForPins(VersionConstraint.parse('^0.0.1')),
        DependencyPinEvaluation.notAPin,
      );
      expect(
        inspectVersionForPins(VersionConstraint.parse('^0.2.4')),
        DependencyPinEvaluation.notAPin,
      );
      expect(
        inspectVersionForPins(VersionConstraint.parse('^1.2.4')),
        DependencyPinEvaluation.notAPin,
      );
    });

    test('1.2.3', () {
      expect(
        inspectVersionForPins(VersionConstraint.parse('1.23.456')),
        DependencyPinEvaluation.directPin,
      );
    });

    test('explicit upper bound <=', () {
      expect(
        inspectVersionForPins(VersionConstraint.parse('>=1.2.3 <=4.0.0')),
        DependencyPinEvaluation.inclusiveMax,
      );
      expect(
        inspectVersionForPins(VersionConstraint.parse('<=4.0.0')),
        DependencyPinEvaluation.inclusiveMax,
      );
    });

    group('when upper bound blocks patch or minor updates', () {
      test('when version starts with 0', () {
        expect(
          inspectVersionForPins(VersionConstraint.parse('>=0.2.3 <0.5.6')),
          DependencyPinEvaluation.blocksMinorBumps,
        );
        expect(
          inspectVersionForPins(VersionConstraint.parse('<0.5.6')),
          DependencyPinEvaluation.blocksMinorBumps,
        );
      });

      test('when version starts with nonzero', () {
        expect(
          inspectVersionForPins(VersionConstraint.parse('>=1.2.3 <4.5.0')),
          DependencyPinEvaluation.blocksMinorBumps,
        );
        expect(
          inspectVersionForPins(VersionConstraint.parse('<4.5.0')),
          DependencyPinEvaluation.blocksMinorBumps,
        );

        expect(
          inspectVersionForPins(VersionConstraint.parse('>=1.2.3 <4.0.6')),
          DependencyPinEvaluation.blocksPatchReleases,
        );
        expect(
          inspectVersionForPins(VersionConstraint.parse('<4.0.6')),
          DependencyPinEvaluation.blocksPatchReleases,
        );

        expect(
          inspectVersionForPins(VersionConstraint.parse('>=1.2.3 <1.2.4')),
          DependencyPinEvaluation.blocksPatchReleases,
        );
        expect(
          inspectVersionForPins(VersionConstraint.parse('>=1.3.0 <1.4.0')),
          DependencyPinEvaluation.blocksMinorBumps,
        );
      });
    });

    test('when upper bound does not allow either patch or minor updates', () {
      expect(
        inspectVersionForPins(VersionConstraint.parse('>=1.2.3 <4.5.6')),
        DependencyPinEvaluation.blocksPatchReleases,
      );
      expect(
        inspectVersionForPins(VersionConstraint.parse('<4.5.6')),
        DependencyPinEvaluation.blocksPatchReleases,
      );
    });

    test('when the maximum version is 0.0.X', () {
      expect(
        inspectVersionForPins(VersionConstraint.parse('>=0.0.1 <0.0.2')),
        DependencyPinEvaluation.blocksMinorBumps,
      );
      expect(
        inspectVersionForPins(VersionConstraint.parse('<0.0.2')),
        DependencyPinEvaluation.blocksMinorBumps,
      );
    });

    test('when the maximum bound contains build', () {
      expect(
        inspectVersionForPins(VersionConstraint.parse('>=0.2.0 <0.3.0+1')),
        DependencyPinEvaluation.buildOrPrerelease,
      );
      expect(
        inspectVersionForPins(VersionConstraint.parse('<0.2.0+1')),
        DependencyPinEvaluation.buildOrPrerelease,
      );

      expect(
        inspectVersionForPins(VersionConstraint.parse('>=1.0.0 <2.0.0+1')),
        DependencyPinEvaluation.buildOrPrerelease,
      );
      expect(
        inspectVersionForPins(VersionConstraint.parse('<2.0.0+1')),
        DependencyPinEvaluation.buildOrPrerelease,
      );
    });

    group('when the maximum bound contains prerelease', () {
      test('', () {
        expect(
          inspectVersionForPins(VersionConstraint.parse('>=0.2.0 <0.3.0-1')),
          DependencyPinEvaluation.buildOrPrerelease,
        );
        expect(
          inspectVersionForPins(VersionConstraint.parse('<0.2.0-1')),
          DependencyPinEvaluation.buildOrPrerelease,
        );

        expect(
          inspectVersionForPins(VersionConstraint.parse('>=1.0.0 <2.0.0-1')),
          DependencyPinEvaluation.buildOrPrerelease,
        );
        expect(
          inspectVersionForPins(VersionConstraint.parse('<2.0.0-1')),
          DependencyPinEvaluation.buildOrPrerelease,
        );
      });

      test('but determines not a pin for prerelease=0', () {
        expect(
          inspectVersionForPins(VersionConstraint.parse('>=0.2.0 <0.3.0-0')),
          DependencyPinEvaluation.notAPin,
        );
        expect(
          inspectVersionForPins(VersionConstraint.parse('<0.2.0-0')),
          DependencyPinEvaluation.notAPin,
        );

        expect(
          inspectVersionForPins(VersionConstraint.parse('>=1.0.0 <2.0.0-0')),
          DependencyPinEvaluation.notAPin,
        );
        expect(
          inspectVersionForPins(VersionConstraint.parse('<2.0.0-0')),
          DependencyPinEvaluation.notAPin,
        );
      });
    });

    group('not a pin when maximum version is', () {
      test('<X.0.0', () {
        expect(
          inspectVersionForPins(VersionConstraint.parse('>=1.0.0 <2.0.0')),
          DependencyPinEvaluation.notAPin,
        );
        expect(
          inspectVersionForPins(VersionConstraint.parse('<2.0.0')),
          DependencyPinEvaluation.notAPin,
        );
      });

      test('<0.X.0', () {
        expect(
          inspectVersionForPins(VersionConstraint.parse('>=0.2.0 <0.3.0')),
          DependencyPinEvaluation.notAPin,
        );
        expect(
          inspectVersionForPins(VersionConstraint.parse('<0.2.0')),
          DependencyPinEvaluation.notAPin,
        );
      });

      test('unset', () {
        expect(
          inspectVersionForPins(VersionConstraint.parse('>=0.2.0')),
          DependencyPinEvaluation.notAPin,
        );
      });
    });
  });
}
