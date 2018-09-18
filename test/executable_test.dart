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

import 'package:test/test.dart';

const String projectWithMissingDeps = 'test_fixtures/missing';
const String projectWithOverPromotedDeps = 'test_fixtures/over_promoted';
const String projectWithUnderPromotedDeps = 'test_fixtures/under_promoted';
const String projectWithUnusedDeps = 'test_fixtures/unused';
const String projectWithAnalyzer = 'test_fixtures/analyzer';
const String projectWithNoProblems = 'test_fixtures/valid';
const String projectWithDependencyPins = 'test_fixtures/dependency_pins';

ProcessResult checkProject(
  String projectPath, {
  List<String> excludeDirs = const [],
  List<String> ignoredPackages = const [],
  bool fatalDevMissing = true,
  bool fatalOverPromoted = true,
  bool fatalMissing = true,
  bool fatalPins = true,
  bool fatalUnderPromoted = true,
  bool fatalUnused = true,
}) {
  Process.runSync('pub', ['get'], workingDirectory: projectPath);

  final args = ['run', 'dependency_validator'];

  if (ignoredPackages.isNotEmpty) args..add('--ignore')..add(ignoredPackages.join(','));
  if (excludeDirs.isNotEmpty) args..add('--exclude-dir')..add(excludeDirs.join(','));
  if (!fatalDevMissing) args.add('--no-fatal-dev-mising');
  if (!fatalMissing) args.add('--no-fatal-missing');
  if (!fatalOverPromoted) args.add('--no-fatal-over-promoted');
  if (!fatalUnderPromoted) args.add('--no-fatal-under-promoted');
  if (!fatalUnused) args.add('--no-fatal-unused');
  if (!fatalPins) args.add('--no-fatal-pins');

  // This makes it easier to print(result.stdout) for debugging tests
  args.add('--verbose');

  return Process.runSync('pub', args, workingDirectory: projectPath);
}

void main() {
  group('dependency_validator', () {
    group('fails when there are packages missing from the pubspec', () {
      test('', () {
        final result = checkProject(projectWithMissingDeps);

        expect(result.exitCode, equals(1));
        expect(result.stderr, contains('These packages are used in lib/ but are not dependencies:'));
        expect(result.stderr, contains('yaml'));
        expect(result.stderr, contains('somescsspackage'));
      });

      test('except when the --no-fatal-missing flag is passed in', () {
        final result = checkProject(projectWithMissingDeps, fatalMissing: false);

        expect(result.exitCode, equals(0));
        expect(result.stderr, contains('These packages are used in lib/ but are not dependencies:'));
        expect(result.stderr, contains('yaml'));
        expect(result.stderr, contains('somescsspackage'));
      });

      test('except when the lib directory is excluded', () {
        final result = checkProject(projectWithMissingDeps, excludeDirs: ['lib/']);

        expect(result.exitCode, equals(0));
        expect(result.stderr, isEmpty);
      });
    });

    group('fails when there are over promoted packages', () {
      test('', () {
        final result = checkProject(projectWithOverPromotedDeps);

        expect(result.exitCode, 1);
        expect(result.stderr,
            contains('These packages are only used outside lib/ and should be downgraded to dev_dependencies:'));
        expect(result.stderr, contains('path'));
        expect(result.stderr, contains('yaml'));
      });

      test('except when the --no-fatal-over-promoted flag is passed in', () {
        final result = checkProject(projectWithOverPromotedDeps, fatalOverPromoted: false);

        expect(result.exitCode, 0);
        expect(result.stderr,
            contains('These packages are only used outside lib/ and should be downgraded to dev_dependencies:'));
        expect(result.stderr, contains('path'));
        expect(result.stderr, contains('yaml'));
      });
    });

    group('fails when there are under promoted packages', () {
      test('', () {
        final result = checkProject(projectWithUnderPromotedDeps);

        expect(result.exitCode, 1);
        expect(
            result.stderr, contains('These packages are used in lib/ and should be promoted to actual dependencies:'));
        expect(result.stderr, contains('logging'));
        expect(result.stderr, contains('yaml'));
      });

      test('except when the --no-fatal-under-promoted flag is passed in', () {
        final result = checkProject(projectWithUnderPromotedDeps, fatalUnderPromoted: false);

        expect(result.exitCode, 0);
        expect(
            result.stderr, contains('These packages are used in lib/ and should be promoted to actual dependencies:'));
        expect(result.stderr, contains('logging'));
        expect(result.stderr, contains('yaml'));
      });
    });

    group('fails when there are unused packages', () {
      test('', () {
        final result = checkProject(projectWithUnusedDeps);

        expect(result.exitCode, 1);
        expect(result.stderr,
            contains('These packages may be unused, or you may be using executables or assets from these packages:'));
        expect(result.stderr, contains('fake_project'));
      });

      test('except when the --no-fatal-unused flag is passed in', () {
        final result = checkProject(projectWithUnusedDeps, fatalUnused: false);

        expect(result.exitCode, 0);
        expect(result.stderr,
            contains('These packages may be unused, or you may be using executables or assets from these packages:'));
        expect(result.stderr, contains('fake_project'));
      });
    });

    test('warns when the analyzer pacakge is depended on but not used', () {
      final result = checkProject(projectWithAnalyzer, ignoredPackages: ['analyzer']);

      expect(result.exitCode, 0);
      expect(result.stderr, contains('You do not need to depend on `analyzer` to run the Dart analyzer.'));
    });

    test('passes when all dependencies are used and valid', () {
      final result = checkProject(projectWithNoProblems);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No fatal infractions found, valid is good to go!'));
    });

    test('passes when there are unused packages, but the unused packages are ignored', () {
      final result = checkProject(projectWithUnusedDeps, ignoredPackages: ['fake_project']);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No fatal infractions found, unused is good to go!'));
    });

    test('passes when there are missing packages, but the missing packages are ignored', () {
      final result = checkProject(projectWithMissingDeps, ignoredPackages: [
        'yaml',
        'somescsspackage',
      ]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No fatal infractions found, missing is good to go!'));
    });

    group('when a dependency is pinned', () {
      test('fails if pins are not ignored', () {
        final result = checkProject(
          projectWithDependencyPins,
          fatalUnused: false,
        );

        expect(result.exitCode, 1);
        expect(result.stderr, contains('These packages are pinned in pubspec.yaml:\n  * coverage'));
      });

      test('warns if pins are ignored', () {
        final result = checkProject(
          projectWithDependencyPins,
          fatalPins: false,
          fatalUnused: false,
        );

        expect(result.exitCode, 0);
        expect(result.stderr, contains('These packages are pinned in pubspec.yaml:\n  * coverage'));
      });
    });
  });
}
