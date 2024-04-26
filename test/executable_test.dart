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

import 'package:io/io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// `master` on build_config has a min sdk bound of dart 3.0.0.
/// Since dependency_validator is still designed to be used on dart 2
/// code, we still want to run unit tests using this older version
///
/// The following ref, is the last commit in build_config that allowed
/// dart 2 as a dependency
const buildConfigRef = 'e2c837b48bd3c4428cb40e2bc1a6cf47d45df8cc';

ProcessResult checkProject(String projectPath,
    {List<String> optionalArgs = const []}) {
  final pubGetResult =
      Process.runSync('dart', ['pub', 'get'], workingDirectory: projectPath);
  if (pubGetResult.exitCode != 0) {
    return pubGetResult;
  }

  final args = [
    'run',
    'dependency_validator',
    // This makes it easier to print(result.stdout) for debugging tests
    '--verbose',
    ...optionalArgs,
  ];

  return Process.runSync('dart', args, workingDirectory: projectPath);
}

/// Removes indentation from `'''` string blocks.
String unindent(String multilineString) {
  var indent = RegExp(r'^( *)').firstMatch(multilineString)![1];
  assert(indent != null && indent.isNotEmpty);
  return multilineString.replaceAll('$indent', '');
}

void main() {
  group('dependency_validator', () {
    late ProcessResult result;

    setUp(() async {
      // Create fake project that any test may use
      final fakeProjectPubspec = unindent('''
          name: fake_project
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <4.0.0'
          dev_dependencies:
            dependency_validator:
              path: ${Directory.current.path}
          dependency_overrides:
            build_config:
              git:
                url: https://github.com/dart-lang/build.git
                path: build_config
                ref: $buildConfigRef
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

    tearDown(() {
      printOnFailure(result.stdout);
      printOnFailure(result.stderr);
    });

    test('fails with incorrect usage', () async {
      final pubspec = unindent('''
          name: common_binaries
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <4.0.0'
          dev_dependencies:
            dependency_validator:
              path: ${Directory.current.path}
          ''');

      await d.dir('common_binaries', [
        d.dir('lib', [
          d.file('fake.dart', 'bool fake = true;'),
        ]),
        d.file('pubspec.yaml', pubspec),
      ]).create();

      result = checkProject('${d.sandbox}/common_binaries',
          optionalArgs: ['-x', 'tool/wdesk_sdk']);

      expect(result.exitCode, ExitCode.usage.code);
    });

    group('fails when there are packages missing from the pubspec', () {
      setUp(() async {
        final pubspec = unindent('''
            name: missing
            version: 0.0.0
            private: true
            environment:
              sdk: '>=2.4.0 <4.0.0'
            dev_dependencies:
              dependency_validator:
                path: ${Directory.current.path}
            dependency_overrides:
              build_config:
                git:
                  url: https://github.com/dart-lang/build.git
                  path: build_config
                  ref: $buildConfigRef
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
        result = checkProject('${d.sandbox}/missing');

        expect(result.exitCode, equals(1));
        expect(
            result.stderr,
            contains(
                'These packages are used in lib/ but are not dependencies:'));
        expect(result.stderr, contains('yaml'));
        expect(result.stderr, contains('somescsspackage'));
      });

      test('except when the lib directory is excluded', () async {
        await d.dir('missing', [
          d.file('dart_dependency_validator.yaml', unindent('''
            exclude:
              - 'lib/**'
            '''))
        ]).create();
        result = checkProject('${d.sandbox}/missing');
        expect(result.exitCode, equals(0));
        expect(result.stderr, isEmpty);
      });

      test(
          'except when the lib directory is excluded (deprecated pubspec method)',
          () {
        final dependencyValidatorSection = unindent('''
            dependency_validator:
              exclude:
                - 'lib/**'
            ''');

        File('${d.sandbox}/missing/pubspec.yaml').writeAsStringSync(
            dependencyValidatorSection,
            mode: FileMode.append,
            flush: true);

        result = checkProject('${d.sandbox}/missing');

        expect(result.exitCode, equals(0));
        expect(
            result.stderr,
            contains(
                'Configuring dependency_validator in pubspec.yaml is deprecated'));
      });

      test('except when they are ignored', () async {
        await d.dir('missing', [
          d.file('dart_dependency_validator.yaml', unindent('''
            ignore:
              - yaml
              - somescsspackage
            '''))
        ]).create();
        result = checkProject('${d.sandbox}/missing');
        expect(result.exitCode, 0);
      });

      test('except when they are ignored (deprecated pubspec method)', () {
        final dependencyValidatorSection = unindent('''
            dependency_validator:
              ignore:
                - yaml
                - somescsspackage
            ''');

        File('${d.sandbox}/missing/pubspec.yaml').writeAsStringSync(
            dependencyValidatorSection,
            mode: FileMode.append);

        result = checkProject('${d.sandbox}/missing');
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
              sdk: '>=2.4.0 <4.0.0'
            dependencies:
              path: any
              yaml: any
            dev_dependencies:
              dependency_validator:
                path: ${Directory.current.path}
            dependency_overrides:
              build_config:
                git:
                  url: https://github.com/dart-lang/build.git
                  path: build_config
                  ref: $buildConfigRef
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
        result = checkProject('${d.sandbox}/over_promoted');

        expect(result.exitCode, 1);
        expect(
            result.stderr,
            contains(
                'These packages are only used outside lib/ and should be downgraded to dev_dependencies:'));
        expect(result.stderr, contains('path'));
        expect(result.stderr, contains('yaml'));
      });

      test('except when they are ignored', () async {
        await d.dir('over_promoted', [
          d.file('dart_dependency_validator.yaml', unindent('''
            ignore:
              - path
              - yaml
            '''))
        ]).create();
        result = checkProject('${d.sandbox}/over_promoted');
        expect(result.exitCode, 0);
      });

      test('except when they are ignored (deprecated pubspec method)', () {
        final dependencyValidatorSection = unindent('''
            dependency_validator:
              ignore:
                - path
                - yaml
            ''');

        File('${d.sandbox}/over_promoted/pubspec.yaml').writeAsStringSync(
            dependencyValidatorSection,
            mode: FileMode.append);

        result = checkProject('${d.sandbox}/over_promoted');
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
              sdk: '>=2.4.0 <4.0.0'
            dev_dependencies:
              logging: any
              yaml: any
              dependency_validator:
                path: ${Directory.current.path}
            dependency_overrides:
              build_config:
                git:
                  url: https://github.com/dart-lang/build.git
                  path: build_config
                  ref: $buildConfigRef
            ''');

        await d.dir('under_promoted', [
          d.dir('lib', [
            d.file('under_promoted.dart',
                'import \'package:logging/logging.dart\';'),
            d.file('under_promoted.scss', '@import \'package:yaml/foo\';'),
          ]),
          d.file('pubspec.yaml', pubspec),
        ]).create();
      });

      test('', () {
        result = checkProject('${d.sandbox}/under_promoted');

        expect(result.exitCode, 1);
        expect(
            result.stderr,
            contains(
                'These packages are used in lib/ and should be promoted to actual dependencies:'));
        expect(result.stderr, contains('logging'));
        expect(result.stderr, contains('yaml'));
      });

      test('except when they are ignored', () async {
        await d.dir('under_promoted', [
          d.file('dart_dependency_validator.yaml', unindent('''
            ignore:
              - logging
              - yaml
            '''))
        ]).create();
        result = checkProject('${d.sandbox}/under_promoted');
        expect(result.exitCode, 0);
      });

      test('except when they are ignored (deprecated pubspec method)', () {
        final dependencyValidatorSection = unindent('''
            dependency_validator:
              ignore:
                - logging
                - yaml
            ''');

        File('${d.sandbox}/under_promoted/pubspec.yaml').writeAsStringSync(
            dependencyValidatorSection,
            mode: FileMode.append);

        result = checkProject('${d.sandbox}/under_promoted');
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
              sdk: '>=2.4.0 <4.0.0'
            dev_dependencies:
              fake_project:
                path: ${d.sandbox}/fake_project
              dependency_validator:
                path: ${Directory.current.path}
            dependency_overrides:
              build_config:
                git:
                  url: https://github.com/dart-lang/build.git
                  path: build_config
                  ref: $buildConfigRef
            ''');

        await d.dir('unused', [
          d.file('pubspec.yaml', unusedPubspec),
        ]).create();
      });

      test('', () {
        result = checkProject('${d.sandbox}/unused');

        expect(result.exitCode, 1);
        expect(
            result.stderr,
            contains(
                'These packages may be unused, or you may be using assets from these packages:'));
        expect(result.stderr, contains('fake_project'));
      });

      test('and import is commented out', () async {
         await d.dir('unused', [
           d.dir('lib', [
            d.file('commented_out.dart', '// import \'package:other_project/other.dart\';'), // commented out import
          ]),
          d.dir('test', [
            d.file('valid.dart', 'import \'package:fake_project/fake.dart\';'),
          ])
        ]).create();
        result = checkProject('${d.sandbox}/unused');
        expect(result.exitCode, 0);
        expect(result.stdout, contains('No dependency issues found!'));
      });

      test('except when they are ignored', () async {
        await d.dir('unused', [
          d.file('dart_dependency_validator.yaml', unindent('''
            ignore:
              - fake_project
              - yaml
            '''))
        ]).create();
        result = checkProject('${d.sandbox}/unused');
        expect(result.exitCode, 0);
        expect(result.stdout, contains('No dependency issues found!'));
      });

      test('except when they are ignored (deprecated pubspec method)', () {
        final dependencyValidatorSection = unindent('''
            dependency_validator:
              ignore:
                - fake_project
                - yaml
            ''');

        File('${d.sandbox}/unused/pubspec.yaml').writeAsStringSync(
            dependencyValidatorSection,
            mode: FileMode.append);

        result = checkProject('${d.sandbox}/unused');
        expect(result.exitCode, 0);
        expect(result.stdout, contains('No dependency issues found!'));
      });
    });

    test('warns when the analyzer package is depended on but not used',
        () async {
      final pubspec = unindent('''
          name: analyzer_dep
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <4.0.0'
          dependencies:
            analyzer: any
          dev_dependencies:
            dependency_validator:
              path: ${Directory.current.path}
          dependency_overrides:
            build_config:
              git:
                url: https://github.com/dart-lang/build.git
                path: build_config
                ref: $buildConfigRef
          ''');

      await d.dir('project', [
        d.dir('lib', [
          d.file('analyzer_dep.dart', ''),
        ]),
        d.file('dart_dependency_validator.yaml', unindent('''
          ignore:
            - analyzer
          ''')),
        d.file('pubspec.yaml', pubspec),
      ]).create();

      result = checkProject('${d.sandbox}/project');

      expect(result.exitCode, 0);
      expect(
          result.stderr,
          contains(
              'You do not need to depend on `analyzer` to run the Dart analyzer.'));
    });

    test('passes when all dependencies are used and valid', () async {
      final pubspec = unindent('''
          name: valid
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <4.0.0'
          dependencies:
            logging: any
            yaml: any
            fake_project:
              path: ${d.sandbox}/fake_project
          dev_dependencies:
            dependency_validator:
              path: ${Directory.current.path}
            pedantic: any
          dependency_overrides:
            build_config:
              git:
                url: https://github.com/dart-lang/build.git
                path: build_config
                ref: $buildConfigRef
          ''');

      final validDotDart = ''
          'import \'package:logging/logging.dart\';'
          'import \'package:fake_project/fake.dart\';'
          '// import \'package:does_not_exist/fake.dart\''; // commented out and unused

      await d.dir('valid', [
        d.dir('lib', [
          d.file('valid.dart', validDotDart),
          d.file('valid.scss', '@import \'package:yaml/foo\';'),
        ]),
        d.file('pubspec.yaml', pubspec),
        d.file('analysis_options.yaml',
            'include: package:pedantic/analysis_options.1.8.0.yaml'),
      ]).create();

      result = checkProject('${d.sandbox}/valid');

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No dependency issues found!'));
    });

    test('passes when dependencies not used provide executables', () async {
      final pubspec = unindent('''
          name: common_binaries
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <4.0.0'
          dev_dependencies:
            build_runner: ^2.3.3
            coverage: any
            dart_style: ^2.3.2
            dependency_validator:
              path: ${Directory.current.path}
          dependency_overrides:
            build_config:
              git:
                url: https://github.com/dart-lang/build.git
                path: build_config
                ref: $buildConfigRef
          ''');

      await d.dir('common_binaries', [
        d.dir('lib', [
          d.file('fake.dart', 'bool fake = true;'),
        ]),
        d.file('pubspec.yaml', pubspec),
      ]).create();

      result = checkProject('${d.sandbox}/common_binaries');

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No dependency issues found!'));
    });

    test('fails when dependencies not used provide executables, but are not dev_dependencies', () async {
      final pubspec = unindent('''
          name: common_binaries
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <4.0.0'
          dependencies:
            build_runner: ^2.3.3
            coverage: any
            dart_style: ^2.3.2
            dependency_validator:
              path: ${Directory.current.path}
          dependency_overrides:
            build_config:
              git:
                url: https://github.com/dart-lang/build.git
                path: build_config
                ref: $buildConfigRef
          ''');

      await d.dir('common_binaries', [
        d.dir('lib', [
          d.file('fake.dart', 'bool fake = true;'),
        ]),
        d.file('pubspec.yaml', pubspec),
      ]).create();

      result = checkProject('${d.sandbox}/common_binaries');

      expect(result.exitCode, 1);
      expect(result.stderr, contains('The following packages contain executables, and are only used outside of lib/. These should be downgraded to dev_dependencies'));
    });

    test(
        'passes when dependencies are not imported but provide auto applied builders',
        () async {
      final pubspec = unindent('''
          name: common_binaries
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <4.0.0'
          dev_dependencies:
            build_test: ^2.0.1
            build_vm_compilers: ^1.0.3
            build_web_compilers: ^3.2.7
            dependency_validator:
              path: ${Directory.current.path}
          dependency_overrides:
            build_config:
              git:
                url: https://github.com/dart-lang/build.git
                path: build_config
                ref: $buildConfigRef
          ''');

      await d.dir('common_binaries', [
        d.dir('lib', [
          d.file('fake.dart', 'bool fake = true;'),
        ]),
        d.file('pubspec.yaml', pubspec),
      ]).create();

      result = checkProject('${d.sandbox}/common_binaries');

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No dependency issues found!'));
    });

    test('passes when dependencies are not imported but provide used builders',
        () async {
      final pubspec = unindent('''
          name: common_binaries
          version: 0.0.0
          private: true
          environment:
            sdk: '>=2.4.0 <4.0.0'
          dev_dependencies:
            fake_project:
              path: ${d.sandbox}/fake_project
            dependency_validator:
              path: ${Directory.current.path}
          dependency_overrides:
            build_config:
              git:
                url: https://github.com/dart-lang/build.git
                path: build_config
                ref: $buildConfigRef
          ''');

      final build = unindent(r'''
            targets:
              $default:
                builders:
                  fake_project|someBuilder:
                    options: {}
            ''');

      await d.dir('common_binaries', [
        d.dir('lib', [
          d.file('nope.dart', 'bool nope = true;'),
        ]),
        d.file('pubspec.yaml', pubspec),
        d.file('build.yaml', build),
      ]).create();

      result = checkProject('${d.sandbox}/common_binaries');

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No dependency issues found!'));
    });

    group('when a dependency is pinned', () {
      setUp(() async {
        final pubspec = unindent('''
            name: dependency_pins
            version: 0.0.0
            private: true
            environment:
              sdk: '>=2.4.0 <4.0.0'
            dependencies:
              logging: 1.0.2
            dev_dependencies:
              dependency_validator:
                path: ${Directory.current.path}
            dependency_overrides:
              build_config:
                git:
                  url: https://github.com/dart-lang/build.git
                  path: build_config
                  ref: $buildConfigRef
            ''');

        await d.dir('dependency_pins', [
          d.file('pubspec.yaml', pubspec),
        ]).create();
      });

      test('fails if pins are not ignored', () {
        result = checkProject('${d.sandbox}/dependency_pins');

        expect(result.exitCode, 1);
        expect(
            result.stderr,
            contains(
                'These packages are pinned in pubspec.yaml:\n  * logging'));
      });

      test('should not fails if package is pinned but pins allowed', () async {
        await d.dir('dependency_pins', [
          d.dir('lib', [
            d.file('test.dart', unindent('''
            import 'package:logging/logging.dart';
            final log = Logger('ExampleLogger');
            ''')),
          ]),
          d.file('dart_dependency_validator.yaml', unindent('''
            allow_pins: true
            '''))
        ]).create();
        result = checkProject('${d.sandbox}/dependency_pins');
        expect(result.exitCode, 0);
        expect(result.stdout, contains('No dependency issues found!'));
      });

      test('ignores infractions if the package is ignored', () async {
        await d.dir('dependency_pins', [
          d.file('dart_dependency_validator.yaml', unindent('''
            ignore:
              - logging
            '''))
        ]).create();
        result = checkProject('${d.sandbox}/dependency_pins');
        expect(result.exitCode, 0);
        expect(result.stdout, contains('No dependency issues found!'));
      });
    });
  });
}
