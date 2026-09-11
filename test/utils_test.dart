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
import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:dependency_validator/src/constants.dart';
import 'package:dependency_validator/src/utils.dart';

import 'utils.dart';

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
      expect(getAnalysisOptionsIncludePackage(path: d.sandbox), 'pedantic');
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

  group('resolveWorkspaceMembers', () {
    test('returns literal workspace paths unchanged', () async {
      await d.dir('root', [
        d.dir('subpackage', [
          d.file('pubspec.yaml', 'name: subpackage\n'),
        ]),
      ]).create();

      expect(
        resolveWorkspaceMembers('${d.sandbox}/root', ['subpackage']),
        ['subpackage'],
      );
    });

    test('expands glob patterns to directories with pubspec.yaml', () async {
      await d.dir('root', [
        d.dir('packages', [
          d.dir('pkg_a', [
            d.file('pubspec.yaml', 'name: pkg_a\n'),
          ]),
          d.dir('pkg_b', [
            d.file('pubspec.yaml', 'name: pkg_b\n'),
          ]),
          d.dir('not_a_package', [
            d.file('README.md', ''),
          ]),
        ]),
      ]).create();

      expect(
        resolveWorkspaceMembers('${d.sandbox}/root', ['packages/*']),
        ['packages/pkg_a', 'packages/pkg_b'],
      );
    });

    test('ignores glob matches without pubspec.yaml', () async {
      await d.dir('root', [
        d.dir('packages', [
          d.dir('pkg_a', [
            d.file('pubspec.yaml', 'name: pkg_a\n'),
          ]),
          d.dir('empty_dir', []),
        ]),
      ]).create();

      expect(
        resolveWorkspaceMembers('${d.sandbox}/root', ['packages/*']),
        ['packages/pkg_a'],
      );
    });

    test('deduplicates overlapping literal and glob paths', () async {
      await d.dir('root', [
        d.dir('packages', [
          d.dir('foo', [
            d.file('pubspec.yaml', 'name: foo\n'),
          ]),
          d.dir('bar', [
            d.file('pubspec.yaml', 'name: bar\n'),
          ]),
        ]),
      ]).create();

      expect(
        resolveWorkspaceMembers('${d.sandbox}/root', [
          'packages/*',
          'packages/foo',
        ]),
        ['packages/bar', 'packages/foo'],
      );
    });

    test('returns sorted results independent of filesystem order', () async {
      await d.dir('root', [
        d.dir('packages', [
          d.dir('zebra', [
            d.file('pubspec.yaml', 'name: zebra\n'),
          ]),
          d.dir('alpha', [
            d.file('pubspec.yaml', 'name: alpha\n'),
          ]),
        ]),
      ]).create();

      expect(
        resolveWorkspaceMembers('${d.sandbox}/root', ['packages/*']),
        ['packages/alpha', 'packages/zebra'],
      );
    });

    test('returns null for invalid glob syntax', () async {
      await d.dir('root', []).create();

      expect(
        resolveWorkspaceMembers('${d.sandbox}/root', ['packages/[a']),
        isNull,
      );
    });

    test('ignores matches in hidden directories', () async {
      await d.dir('root', [
        d.dir('packages', [
          d.dir('pkg_a', [
            d.file('pubspec.yaml', 'name: pkg_a\n'),
          ]),
          d.dir('.hidden_pkg', [
            d.file('pubspec.yaml', 'name: hidden_pkg\n'),
          ]),
        ]),
        d.dir('.dart_tool', [
          d.dir('tool_pkg', [
            d.file('pubspec.yaml', 'name: tool_pkg\n'),
          ]),
        ]),
      ]).create();

      expect(
        resolveWorkspaceMembers('${d.sandbox}/root', ['packages/*', '*/*']),
        ['packages/pkg_a'],
      );
    });

    test('returns null when literal path is the workspace root itself', () async {
      await d.dir('root', [
        d.file('pubspec.yaml', 'name: root\n'),
      ]).create();

      expect(
        resolveWorkspaceMembers('${d.sandbox}/root', ['.']),
        isNull,
      );
      expect(
        resolveWorkspaceMembers('${d.sandbox}/root', ['./']),
        isNull,
      );
    });

    test('returns null when literal path escapes the workspace root', () async {
      await d.dir('root', [
        d.file('pubspec.yaml', 'name: root\n'),
      ]).create();

      expect(
        resolveWorkspaceMembers('${d.sandbox}/root', ['../outside']),
        isNull,
      );
    });

    test('returns null when literal path is an absolute path outside root', () async {
      await d.dir('root', [
        d.file('pubspec.yaml', 'name: root\n'),
      ]).create();

      expect(
        resolveWorkspaceMembers('${d.sandbox}/root', ['/some/absolute/path']),
        isNull,
      );
    });

    group('logging', () {
      late List<LogRecord> records;
      late StreamSubscription<LogRecord> subscription;

      setUp(() {
        records = [];
        Logger.root.level = Level.ALL;
        subscription = Logger.root.onRecord.listen(records.add);
      });

      tearDown(() => subscription.cancel());

      test('warns when a glob matches no package directories', () async {
        await d.dir('root', [
          d.dir('packages', [
            d.dir('not_a_package', [d.file('README.md', '')]),
          ]),
        ]).create();

        expect(
          resolveWorkspaceMembers('${d.sandbox}/root', ['packages/*']),
          isEmpty,
        );
        expect(
          records.where((r) => r.level == Level.WARNING).map((r) => r.message),
          [contains('No workspace packages matching "packages/*"')],
        );
      });

      test('warns when a glob matches nothing at all', () async {
        await d.dir('root', []).create();

        expect(
          resolveWorkspaceMembers('${d.sandbox}/root', ['missing/*']),
          isEmpty,
        );
        expect(
          records.map((r) => r.message),
          [contains('No workspace packages matching "missing/*"')],
        );
      });

      test('does not warn when a glob matches a package', () async {
        await d.dir('root', [
          d.dir('packages', [
            d.dir('pkg_a', [d.file('pubspec.yaml', 'name: pkg_a\n')]),
          ]),
        ]).create();

        expect(
          resolveWorkspaceMembers('${d.sandbox}/root', ['packages/*']),
          ['packages/pkg_a'],
        );
        expect(records, isEmpty);
      });

      test(
        'returns null and shouts when a glob directory cannot be listed',
        () async {
          await d.dir('root', [
            d.dir('packages', [
              d.dir('pkg_a', [d.file('pubspec.yaml', 'name: pkg_a\n')]),
            ]),
          ]).create();
          final packagesDir = Directory('${d.sandbox}/root/packages');
          await Process.run('chmod', ['000', packagesDir.path]);
          addTearDown(() => Process.run('chmod', ['755', packagesDir.path]));

          expect(
            resolveWorkspaceMembers('${d.sandbox}/root', ['packages/*']),
            isNull,
          );
          expect(
            records.where((r) => r.level == Level.SHOUT).map((r) => r.message),
            [contains('failed to list workspace glob "packages/*"')],
          );
        },
        // Relies on POSIX permissions being enforced for the current user.
        skip: Platform.isWindows || Platform.environment['USER'] == 'root',
      );
    });
  });

  group('hasGlobWildcards', () {
    test('detects glob syntax', () {
      expect(hasGlobWildcards('packages/*'), isTrue);
      expect(hasGlobWildcards('apps/nested/pkg?'), isTrue);
      expect(hasGlobWildcards('packages/[abc]'), isTrue);
      expect(hasGlobWildcards('packages/{a,b}'), isTrue);
      expect(hasGlobWildcards('packages/pkg]'), isTrue);
      expect(hasGlobWildcards('packages/pkg}'), isTrue);
    });

    test('returns false for literal paths', () {
      expect(hasGlobWildcards('packages/subpackage'), isFalse);
      expect(hasGlobWildcards('packages/sub-package'), isFalse);
      expect(hasGlobWildcards('packages/sub_package'), isFalse);
    });
  });

  group('listNestedPackages', () {
    test('returns empty when no directory exists', () {
      expect(listNestedPackages('${d.sandbox}/non_existent'), isEmpty);
    });

    test('returns empty when only root pubspec exists', () async {
      await d.dir('pkg', [
        d.file('pubspec.yaml', 'name: pkg'),
        d.dir('lib', [d.file('pkg.dart', 'void main() {}')]),
      ]).create();

      expect(listNestedPackages('${d.sandbox}/pkg'), isEmpty);
    });

    test('discovers nested packages in subdirectories', () async {
      await d.dir('complex_pkg', [
        d.file('pubspec.yaml', 'name: complex_pkg'),
        d.dir('lib', [d.file('main.dart', 'void main() {}')]),
        d.dir('example', [
          d.dir('host_name', [
            d.file('pubspec.yaml', 'name: host_name'),
            d.dir('tool', [d.file('ffigen.dart', 'void main() {}')]),
          ]),
        ]),
        d.dir('pkgs', [
          d.dir('nested_sub', [
            d.file('pubspec.yaml', 'name: nested_sub'),
            d.dir('lib', [d.file('nested.dart', 'void main() {}')]),
          ]),
        ]),
        d.dir('.dart_tool', [
          d.dir('hidden_sub', [
            d.file('pubspec.yaml', 'name: hidden_sub'),
          ]),
        ]),
      ]).create();

      final nested = listNestedPackages('${d.sandbox}/complex_pkg')
          .map((dir) => p.relative(dir.path, from: '${d.sandbox}/complex_pkg'))
          .toList()
        ..sort();

      expect(nested, [
        p.join('example', 'host_name'),
        p.join('pkgs', 'nested_sub'),
      ]);
    });
  });

  group('checkWorkspace', () {
    test(
      'throws ArgumentError when mixing subpackages and subpackage params',
      () async {
        expect(
          () => checkWorkspace(
            workspace: [],
            workspaceDeps: {},
            subpackages: [],
            subpackage: [],
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
