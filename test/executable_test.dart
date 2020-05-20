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
import 'package:test_descriptor/test_descriptor.dart';

ProcessResult checkProject(String projectPath) {
  Process.runSync('pub', ['get'], workingDirectory: projectPath);

  final args = [
    'run',
    'dependency_validator',
    // This makes it easier to print(result.stdout) for debugging tests
    '--verbose',
  ];

  return Process.runSync('pub', args, workingDirectory: projectPath);
}

void main() {
  group('dependency_validator', () {
    setUp(() async {
      // Create fake project that any test may use
      final fakeProjectPubspec = ''
          'name: fake_project\n'
          'version: 0.0.0\n'
          'private: true\n'
          'environment:\n'
          '  sdk: \'>=2.4.0 <3.0.0\'\n'
          'dev_dependencies:\n'
          '  dependency_validator:\n'
          '    path: ${Directory.current.path}\n';

      await dir('fake_project', [
        dir('lib', [
          file('fake.dart', 'bool fake = true;'),
        ]),
        file('pubspec.yaml', fakeProjectPubspec),
      ]).create();
    });

    group('fails when there are packages missing from the pubspec', () {
      setUp(() async {
        final pubspec = ''
            'name: missing\n'
            'version: 0.0.0\n'
            'private: true\n'
            'environment:\n'
            '  sdk: \'>=2.4.0 <3.0.0\'\n'
            'dev_dependencies:\n'
            '  dependency_validator:\n'
            '    path: ${Directory.current.path}\n';

        await dir('missing', [
          dir('lib', [
            file('missing.dart', 'import \'package:yaml/yaml.dart\';'),
            file('missing.scss', '@import \'package:somescsspackage/foo\';'),
          ]),
          file('pubspec.yaml', pubspec),
        ]).create();
      });

      test('', () {
        final result = checkProject('$sandbox/missing');

        expect(result.exitCode, equals(1));
        expect(result.stderr, contains('These packages are used in lib/ but are not dependencies:'));
        expect(result.stderr, contains('yaml'));
        expect(result.stderr, contains('somescsspackage'));
      });

      test('except when the lib directory is excluded', () {
        final dependencyValidatorSection = ''
            'dependency_validator:\n'
            '  exclude:\n'
            '    - \'lib/**\'\n';

        File('$sandbox/missing/pubspec.yaml').writeAsStringSync(dependencyValidatorSection, mode: FileMode.append);

        final result = checkProject('$sandbox/missing');

        expect(result.exitCode, equals(0));
        expect(result.stderr, isEmpty);
      });

      test('except when they are ignored', () {
        final dependencyValidatorSection = ''
            'dependency_validator:\n'
            '  ignore:\n'
            '    - yaml\n'
            '    - somescsspackage\n';

        File('$sandbox/missing/pubspec.yaml').writeAsStringSync(dependencyValidatorSection, mode: FileMode.append);

        final result = checkProject('$sandbox/missing');
        expect(result.exitCode, 0);
      });
    });

    group('fails when there are over promoted packages', () {
      setUp(() async {
        final pubspec = ''
            'name: over_promoted\n'
            'version: 0.0.0\n'
            'private: true\n'
            'environment:\n'
            '  sdk: \'>=2.4.0 <3.0.0\'\n'
            'dependencies:\n'
            '  path: any\n'
            '  yaml: any\n'
            'dev_dependencies:\n'
            '  dependency_validator:\n'
            '    path: ${Directory.current.path}\n';

        await dir('over_promoted', [
          dir('web', [
            file('main.dart', 'import \'package:path/path.dart\';'),
            file('over_promoted.scss', '@import \'package:yaml/foo\';'),
          ]),
          file('pubspec.yaml', pubspec),
        ]).create();
      });

      test('', () {
        final result = checkProject('$sandbox/over_promoted');

        expect(result.exitCode, 1);
        expect(result.stderr,
            contains('These packages are only used outside lib/ and should be downgraded to dev_dependencies:'));
        expect(result.stderr, contains('path'));
        expect(result.stderr, contains('yaml'));
      });

      test('except when they are ignored', () {
        final dependencyValidatorSection = ''
            'dependency_validator:\n'
            '  ignore:\n'
            '    - path\n'
            '    - yaml\n';

        File('$sandbox/over_promoted/pubspec.yaml')
            .writeAsStringSync(dependencyValidatorSection, mode: FileMode.append);

        final result = checkProject('$sandbox/over_promoted');
        expect(result.exitCode, 0);
      });
    });

    group('fails when there are under promoted packages', () {
      setUp(() async {
        final pubspec = ''
            'name: under_promoted\n'
            'version: 0.0.0\n'
            'private: true\n'
            'environment:\n'
            '  sdk: \'>=2.4.0 <3.0.0\'\n'
            'dev_dependencies:\n'
            '  logging: any\n'
            '  yaml: any\n'
            '  dependency_validator:\n'
            '    path: ${Directory.current.path}\n';

        await dir('under_promoted', [
          dir('lib', [
            file('under_promoted.dart', 'import \'package:logging/logging.dart\';'),
            file('under_promoted.scss', '@import \'package:yaml/foo\';'),
          ]),
          file('pubspec.yaml', pubspec),
        ]).create();
      });

      test('', () {
        final result = checkProject('$sandbox/under_promoted');

        expect(result.exitCode, 1);
        expect(
            result.stderr, contains('These packages are used in lib/ and should be promoted to actual dependencies:'));
        expect(result.stderr, contains('logging'));
        expect(result.stderr, contains('yaml'));
      });

      test('except when they are ignored', () {
        final dependencyValidatorSection = ''
            'dependency_validator:\n'
            '  ignore:\n'
            '    - logging\n'
            '    - yaml\n';

        File('$sandbox/under_promoted/pubspec.yaml')
            .writeAsStringSync(dependencyValidatorSection, mode: FileMode.append);

        final result = checkProject('$sandbox/under_promoted');
        expect(result.exitCode, 0);
      });
    });

    group('fails when there are unused packages', () {
      setUp(() async {
        final unusedPubspec = ''
            'name: unused\n'
            'version: 0.0.0\n'
            'private: true\n'
            'environment:\n'
            '  sdk: \'>=2.4.0 <3.0.0\'\n'
            'dev_dependencies:\n'
            '  fake_project:\n'
            '    path: $sandbox/fake_project\n'
            '  dependency_validator:\n'
            '    path: ${Directory.current.path}\n';

        await dir('unused', [
          file('pubspec.yaml', unusedPubspec),
        ]).create();
      });

      test('', () {
        final result = checkProject('$sandbox/unused');

        expect(result.exitCode, 1);
        expect(result.stderr,
            contains('These packages may be unused, or you may be using executables or assets from these packages:'));
        expect(result.stderr, contains('fake_project'));
      });

      test('except when they are ignored', () {
        final dependencyValidatorSection = ''
            'dependency_validator:\n'
            '  ignore:\n'
            '    - fake_project\n'
            '    - yaml\n';

        File('$sandbox/unused/pubspec.yaml').writeAsStringSync(dependencyValidatorSection, mode: FileMode.append);

        final result = checkProject('$sandbox/unused');
        expect(result.exitCode, 0);
        expect(result.stdout, contains('No fatal infractions found, unused is good to go!'));
      });
    });

    test('warns when the analyzer package is depended on but not used', () async {
      final pubspec = ''
          'name: analyzer_dep\n'
          'version: 0.0.0\n'
          'private: true\n'
          'environment:\n'
          '  sdk: \'>=2.4.0 <3.0.0\'\n'
          'dependencies:\n'
          '  analyzer: any\n'
          'dev_dependencies:\n'
          '  dependency_validator:\n'
          '    path: ${Directory.current.path}\n'
          'dependency_validator:\n'
          '  ignore:\n'
          '    - analyzer\n';

      await dir('project', [
        dir('lib', [
          file('analyzer_dep.dart', ''),
        ]),
        file('pubspec.yaml', pubspec),
      ]).create();

      final result = checkProject('$sandbox/project');

      expect(result.exitCode, 0);
      expect(result.stderr, contains('You do not need to depend on `analyzer` to run the Dart analyzer.'));
    });

    test('passes when all dependencies are used and valid', () async {
      final pubspec = ''
          'name: valid\n'
          'version: 0.0.0\n'
          'private: true\n'
          'environment:\n'
          '  sdk: \'>=2.4.0 <3.0.0\'\n'
          'dependencies:\n'
          '  logging: any\n'
          '  yaml: any\n'
          '  fake_project:\n'
          '    path: $sandbox/fake_project\n'
          'dev_dependencies:\n'
          '  dependency_validator:\n'
          '    path: ${Directory.current.path}\n'
          '  pedantic: any\n';

      final validDotDart = ''
          'import \'package:logging/logging.dart\';'
          'import \'package:fake_project/fake.dart\';';

      await dir('valid', [
        dir('lib', [
          file('valid.dart', validDotDart),
          file('valid.scss', '@import \'package:yaml/foo\';'),
        ]),
        file('pubspec.yaml', pubspec),
        file('analysis_options.yaml', 'include: package:pedantic/analysis_options.1.8.0.yaml'),
      ]).create();

      final result = checkProject('$sandbox/valid');

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No fatal infractions found, valid is good to go!'));
    });

    test('passes when there are unused known common binary packages', () async {
      final pubspec = ''
          'name: common_binaries\n'
          'version: 0.0.0\n'
          'private: true\n'
          'environment:\n'
          '  sdk: \'>=2.4.0 <3.0.0\'\n'
          'dev_dependencies:\n'
          '  build_runner: ^1.7.1\n'
          '  build_test: ^0.10.9\n'
          '  build_vm_compilers: ^1.0.3\n'
          '  build_web_compilers: ^2.5.1\n'
          '  built_value_generator: ^7.0.0\n'
          '  coverage: any\n'
          '  dart_dev: ^3.0.0\n'
          '  dart_style: ^1.3.3\n'
          '  dependency_validator:\n'
          '    path: ${Directory.current.path}\n';

      await dir('common_binaries', [
        dir('lib', [
          file('fake.dart', 'bool fake = true;'),
        ]),
        file('pubspec.yaml', pubspec),
      ]).create();

      final result = checkProject('$sandbox/common_binaries');

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No fatal infractions found, common_binaries is good to go!'));
    });

    group('when a dependency is pinned', () {
      setUp(() async {
        final pubspec = ''
            'name: dependency_pins\n'
            'version: 0.0.0\n'
            'private: true\n'
            'environment:\n'
            '  sdk: \'>=2.4.0 <3.0.0\'\n'
            'dev_dependencies:\n'
            '  logging: \'>=0.9.3 <=0.13.0\'\n'
            '  dependency_validator:\n'
            '    path: ${Directory.current.path}\n';

        await dir('dependency_pins', [
          file('pubspec.yaml', pubspec),
        ]).create();
      });

      test('fails if pins are not ignored', () {
        final result = checkProject('$sandbox/dependency_pins');

        expect(result.exitCode, 1);
        expect(result.stderr, contains('These packages are pinned in pubspec.yaml:\n  * logging'));
      });

      test('ignores infractions if the package is ignored', () {
        final dependencyValidatorSection = ''
            'dependency_validator:\n'
            '  ignore:\n'
            '    - logging\n';

        File('$sandbox/dependency_pins/pubspec.yaml').writeAsStringSync(dependencyValidatorSection, mode: FileMode.append);

        final result = checkProject('$sandbox/dependency_pins');

        expect(result.exitCode, 0);
        expect(result.stdout, contains('No fatal infractions found, dependency_pins is good to go'));
      });
    });
  });
}
