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
import 'package:test_descriptor/test_descriptor.dart' as d;

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

/// Removes indentation from `'''` string blocks.
String unindent(String multilineString) {
  var indent = RegExp(r'^( *)').firstMatch(multilineString)[1];
  assert(indent != null && indent.isNotEmpty);
  return multilineString.replaceAll('$indent', '');
}

void main() {
  group('dependency_validator', () {
    setUp(() async {
      // Create fake project that any test may use
      final fakeProjectPubspec = unindent('''
          name: fake_project
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <3.0.0'
          dev_dependencies:
            dependency_validator:
              path: ${Directory.current.path}
          ''');

      final fakeProjectBuild = unindent('''
          builders:
            someBuilder:
              import: "package:fake_project/builder.dart"
              builder_factories: ["someBuilder"]
              build_extensions: {".dart" : [".woot.g.dart"]}
              auto_apply: none
              build_to: cache
          ''');

      await d.dir('fake_project', [
        d.dir('lib', [
          d.file('fake.dart', 'bool fake = true;'),
          d.file('builder.dart', 'bool fake = true;'),
        ]),
        d.file('pubspec.yaml', fakeProjectPubspec),
        d.file('build.yaml', fakeProjectBuild),
      ]).create();
    });

    group('fails when there are packages missing from the pubspec', () {
      setUp(() async {
        final pubspec = unindent('''
            name: missing
            version: 0.0.0
            private: true
            environment:
              sdk: '>=2.4.0 <3.0.0'
            dev_dependencies:
              dependency_validator:
                path: ${Directory.current.path}
            ''');

        await d.dir('missing', [
          d.dir('lib', [
            d.file('missing.dart', 'import \'package:yaml/yaml.dart\';'),
            d.file('missing.scss', '@import \'package:somescsspackage/foo\';'),
          ]),
          d.file('pubspec.yaml', pubspec),
        ]).create();
      });

      test('', () {
        final result = checkProject('${d.sandbox}/missing');

        expect(result.exitCode, equals(1));
        expect(result.stderr, contains('These packages are used in lib/ but are not dependencies:'));
        expect(result.stderr, contains('yaml'));
        expect(result.stderr, contains('somescsspackage'));
      });

      test('except when the lib directory is excluded', () {
        final dependencyValidatorSection = unindent('''
            dependency_validator:
              exclude:
                - 'lib/**'
            ''');

        File('${d.sandbox}/missing/pubspec.yaml')
            .writeAsStringSync(dependencyValidatorSection, mode: FileMode.append, flush: true);

        final result = checkProject('${d.sandbox}/missing');

        expect(result.exitCode, equals(0));
        expect(result.stderr, isEmpty);
      });

      test('except when they are ignored', () {
        final dependencyValidatorSection = unindent('''
            dependency_validator:
              ignore:
                - yaml
                - somescsspackage
            ''');

        File('${d.sandbox}/missing/pubspec.yaml').writeAsStringSync(dependencyValidatorSection, mode: FileMode.append);

        final result = checkProject('${d.sandbox}/missing');
        expect(result.exitCode, 0);
      });
    });

    group('fails when there are over promoted packages', () {
      setUp(() async {
        final pubspec = unindent('''
            name: over_promoted
            version: 0.0.0
            private: true
            environment:
              sdk: '>=2.4.0 <3.0.0'
            dependencies:
              path: any
              yaml: any
            dev_dependencies:
              dependency_validator:
                path: ${Directory.current.path}
            ''');

        await d.dir('over_promoted', [
          d.dir('web', [
            d.file('main.dart', 'import \'package:path/path.dart\';'),
            d.file('over_promoted.scss', '@import \'package:yaml/foo\';'),
          ]),
          d.file('pubspec.yaml', pubspec),
        ]).create();
      });

      test('', () {
        final result = checkProject('${d.sandbox}/over_promoted');

        expect(result.exitCode, 1);
        expect(result.stderr,
            contains('These packages are only used outside lib/ and should be downgraded to dev_dependencies:'));
        expect(result.stderr, contains('path'));
        expect(result.stderr, contains('yaml'));
      });

      test('except when they are ignored', () {
        final dependencyValidatorSection = unindent('''
            dependency_validator:
              ignore:
                - path
                - yaml
            ''');

        File('${d.sandbox}/over_promoted/pubspec.yaml')
            .writeAsStringSync(dependencyValidatorSection, mode: FileMode.append);

        final result = checkProject('${d.sandbox}/over_promoted');
        expect(result.exitCode, 0);
      });
    });

    group('fails when there are under promoted packages', () {
      setUp(() async {
        final pubspec = unindent('''
            name: under_promoted
            version: 0.0.0
            private: true
            environment:
              sdk: '>=2.4.0 <3.0.0'
            dev_dependencies:
              logging: any
              yaml: any
              dependency_validator:
                path: ${Directory.current.path}
            ''');

        await d.dir('under_promoted', [
          d.dir('lib', [
            d.file('under_promoted.dart', 'import \'package:logging/logging.dart\';'),
            d.file('under_promoted.scss', '@import \'package:yaml/foo\';'),
          ]),
          d.file('pubspec.yaml', pubspec),
        ]).create();
      });

      test('', () {
        final result = checkProject('${d.sandbox}/under_promoted');

        expect(result.exitCode, 1);
        expect(
            result.stderr, contains('These packages are used in lib/ and should be promoted to actual dependencies:'));
        expect(result.stderr, contains('logging'));
        expect(result.stderr, contains('yaml'));
      });

      test('except when they are ignored', () {
        final dependencyValidatorSection = unindent('''
            dependency_validator:
              ignore:
                - logging
                - yaml
            ''');

        File('${d.sandbox}/under_promoted/pubspec.yaml')
            .writeAsStringSync(dependencyValidatorSection, mode: FileMode.append);

        final result = checkProject('${d.sandbox}/under_promoted');
        expect(result.exitCode, 0);
      });
    });

    group('fails when there are unused packages', () {
      setUp(() async {
        final unusedPubspec = unindent('''
            name: unused
            version: 0.0.0
            private: true
            environment:
              sdk: '>=2.4.0 <3.0.0'
            dev_dependencies:
              fake_project:
                path: ${d.sandbox}/fake_project
              dependency_validator:
                path: ${Directory.current.path}
            ''');

        await d.dir('unused', [
          d.file('pubspec.yaml', unusedPubspec),
        ]).create();
      });

      test('', () {
        final result = checkProject('${d.sandbox}/unused');

        expect(result.exitCode, 1);
        expect(
            result.stderr, contains('These packages may be unused, or you may be using assets from these packages:'));
        expect(result.stderr, contains('fake_project'));
      });

      test('except when they are ignored', () {
        final dependencyValidatorSection = unindent('''
            dependency_validator:
              ignore:
                - fake_project
                - yaml
            ''');

        File('${d.sandbox}/unused/pubspec.yaml').writeAsStringSync(dependencyValidatorSection, mode: FileMode.append);

        final result = checkProject('${d.sandbox}/unused');
        expect(result.exitCode, 0);
        expect(result.stdout, contains('No fatal infractions found, unused is good to go!'));
      });
    });

    test('warns when the analyzer package is depended on but not used', () async {
      final pubspec = unindent('''
          name: analyzer_dep
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <3.0.0'
          dependencies:
            analyzer: any
          dev_dependencies:
            dependency_validator:
              path: ${Directory.current.path}
          dependency_validator:
            ignore:
              - analyzer
          ''');

      await d.dir('project', [
        d.dir('lib', [
          d.file('analyzer_dep.dart', ''),
        ]),
        d.file('pubspec.yaml', pubspec),
      ]).create();

      final result = checkProject('${d.sandbox}/project');

      expect(result.exitCode, 0);
      expect(result.stderr, contains('You do not need to depend on `analyzer` to run the Dart analyzer.'));
    });

    test('passes when all dependencies are used and valid', () async {
      final pubspec = unindent('''
          name: valid
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <3.0.0'
          dependencies:
            logging: any
            yaml: any
            fake_project:
              path: ${d.sandbox}/fake_project
          dev_dependencies:
            dependency_validator:
              path: ${Directory.current.path}
            pedantic: any\
          ''');

      final validDotDart = ''
          'import \'package:logging/logging.dart\';'
          'import \'package:fake_project/fake.dart\';';

      await d.dir('valid', [
        d.dir('lib', [
          d.file('valid.dart', validDotDart),
          d.file('valid.scss', '@import \'package:yaml/foo\';'),
        ]),
        d.file('pubspec.yaml', pubspec),
        d.file('analysis_options.yaml', 'include: package:pedantic/analysis_options.1.8.0.yaml'),
      ]).create();

      final result = checkProject('${d.sandbox}/valid');

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No fatal infractions found, valid is good to go!'));
    });

    test('passes when dependencies not used in lib provide executables', () async {
      final pubspec = unindent('''
          name: common_binaries
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <3.0.0'
          dev_dependencies:
            build_runner: ^1.7.1
            coverage: any
            dart_dev: ^3.0.0
            dart_style: ^1.3.3
            dependency_validator:
              path: ${Directory.current.path}
          ''');

      await d.dir('common_binaries', [
        d.dir('lib', [
          d.file('fake.dart', 'bool fake = true;'),
        ]),
        d.file('pubspec.yaml', pubspec),
      ]).create();

      final result = checkProject('${d.sandbox}/common_binaries');

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No fatal infractions found, common_binaries is good to go!'));
    });

    test('passes when dependencies not used in lib provide auto applied builders', () async {
      final pubspec = unindent('''
          name: common_binaries
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <3.0.0'
          dev_dependencies:
            build_test: ^0.10.9
            build_vm_compilers: ^1.0.3
            build_web_compilers: ^2.5.1
            built_value_generator: ^7.0.0
            dependency_validator:
              path: ${Directory.current.path}
          ''');

      await d.dir('common_binaries', [
        d.dir('lib', [
          d.file('fake.dart', 'bool fake = true;'),
        ]),
        d.file('pubspec.yaml', pubspec),
      ]).create();

      final result = checkProject('${d.sandbox}/common_binaries');

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No fatal infractions found, common_binaries is good to go!'));
    });

    test('passes when dependencies not used in lib provide used builders', () async {
      final pubspec = unindent('''
          name: common_binaries
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <3.0.0'
          dev_dependencies:
            fake_project:
              path: ${d.sandbox}/fake_project
            dependency_validator:
              path: ${Directory.current.path}
          ''');

      final build = unindent(r'''
            targets:
              $default:
                builders:
                  fake_project|someBuilder:
            ''');

      await d.dir('common_binaries', [
        d.dir('lib', [
          d.file('nope.dart', 'bool nope = true;'),
        ]),
        d.file('pubspec.yaml', pubspec),
        d.file('build.yaml', build),
      ]).create();

      final result = checkProject('${d.sandbox}/common_binaries');

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No fatal infractions found, common_binaries is good to go!'));
    });

    group('when a dependency is pinned', () {
      setUp(() async {
        final pubspec = unindent('''
            name: dependency_pins
            version: 0.0.0
            private: true
            environment:
              sdk: '>=2.4.0 <3.0.0'
            dev_dependencies:
              logging: '>=0.9.3 <=0.13.0'
              dependency_validator:
                path: ${Directory.current.path}
            ''');

        await d.dir('dependency_pins', [
          d.file('pubspec.yaml', pubspec),
        ]).create();
      });

      test('fails if pins are not ignored', () {
        final result = checkProject('${d.sandbox}/dependency_pins');

        expect(result.exitCode, 1);
        expect(result.stderr, contains('These packages are pinned in pubspec.yaml:\n  * logging'));
      });

      test('ignores infractions if the package is ignored', () {
        final dependencyValidatorSection = unindent('''
            dependency_validator:
              ignore:
                - logging
            ''');

        File('${d.sandbox}/dependency_pins/pubspec.yaml')
            .writeAsStringSync(dependencyValidatorSection, mode: FileMode.append);

        final result = checkProject('${d.sandbox}/dependency_pins');

        expect(result.exitCode, 0);
        expect(result.stdout, contains('No fatal infractions found, dependency_pins is good to go'));
      });
    });
  });
}
