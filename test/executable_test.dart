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

import 'package:dependency_validator/src/pubspec_config.dart';
import 'package:io/io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'utils.dart';

void main() {
  group('dependency_validator', () {
    late ProcessResult result;

    tearDown(() {
      printOnFailure(result.stdout);
      printOnFailure(result.stderr);
    });

    test('fails with incorrect usage', () async {
      result = await checkProject(args: ['-x', 'tool/wdesk_sdk']);
      expect(result.exitCode, ExitCode.usage.code);
    });

    group('fails when there are packages missing from the pubspec', () {
      final project = [
        d.dir('lib', [
          d.file('missing.dart', 'import "package:yaml/yaml.dart";'),
          d.file('missing.scss', '@import "package:some_scss_package/foo";'),
        ]),
      ];

      test('', () async {
        result = await checkProject(project: project);
        expect(result.exitCode, 1);
        expect(
          result.stderr,
          contains('These packages are used in lib/ but are not dependencies:'),
        );
        expect(result.stderr, contains('yaml'));
        expect(result.stderr, contains('some_scss_package'));
      });

      final excludeLib = DepValidatorConfig(exclude: ['lib/**']);
      final ignorePackages = DepValidatorConfig(
        ignore: ['yaml', 'some_scss_package'],
      );

      test('except when lib is excluded', () async {
        result = await checkProject(project: project, config: excludeLib);
        expect(result.exitCode, 0);
        expect(result.stderr, isEmpty);
      });

      test('except when lib is excluded (deprecated pubspec method)', () async {
        result = await checkProject(
          project: project,
          config: excludeLib,
          embedConfigInPubspec: true,
        );

        expect(result.exitCode, equals(0));
        expect(
          result.stderr,
          contains(
            'Configuring dependency_validator in pubspec.yaml is deprecated',
          ),
        );
      });

      test('except when they are ignored', () async {
        result = await checkProject(project: project, config: ignorePackages);
        expect(result.exitCode, 0);
      });

      test(
        'except when they are ignored (deprecated pubspec method)',
        () async {
          result = await checkProject(
            project: project,
            config: ignorePackages,
            embedConfigInPubspec: true,
          );
          expect(result.exitCode, 0);
        },
      );
    });

    group('fails when there are over promoted packages', () {
      final project = [
        d.dir('web', [
          d.file('main.dart', 'import "package:path/path.dart";'),
          d.file('over_promoted.scss', '@import "package:yaml/foo";'),
        ]),
      ];
      final dependencies = {"path": hostedAny, "yaml": hostedAny};
      final config = DepValidatorConfig(ignore: ['path', 'yaml']);

      test('', () async {
        result = await checkProject(
          project: project,
          dependencies: dependencies,
        );

        expect(result.exitCode, 1);
        expect(
          result.stderr,
          contains(
            'These packages are only used outside lib/ and should be downgraded to dev_dependencies:',
          ),
        );
        expect(result.stderr, contains('path'));
        expect(result.stderr, contains('yaml'));
      });

      test('except when they are ignored', () async {
        result = await checkProject(
          project: project,
          dependencies: dependencies,
          config: config,
        );
        expect(result.exitCode, 0);
      });

      test(
        'except when they are ignored (deprecated pubspec method)',
        () async {
          result = await checkProject(
            project: project,
            dependencies: dependencies,
            config: config,
            embedConfigInPubspec: true,
          );
          expect(result.exitCode, 0);
        },
      );
    });

    group('fails when there are under promoted packages', () {
      final devDependencies = {"logging": hostedAny, "yaml": hostedAny};

      final project = [
        d.dir('lib', [
          d.file('main.dart', 'import "package:logging/logging.dart";'),
          d.file('main.scss', '@import "package:yaml/foo";'),
        ]),
      ];

      final config = DepValidatorConfig(ignore: ['logging', 'yaml']);

      test('', () async {
        result = await checkProject(
          project: project,
          devDependencies: devDependencies,
        );
        expect(result.exitCode, 1);
        expect(
          result.stderr,
          contains(
            'These packages are used in lib/ and should be promoted to actual dependencies:',
          ),
        );
        expect(result.stderr, contains('logging'));
        expect(result.stderr, contains('yaml'));
      });

      test('except when they are ignored', () async {
        result = await checkProject(
          project: project,
          devDependencies: devDependencies,
          config: config,
        );
        expect(result.exitCode, 0);
      });

      test(
        'except when they are ignored (deprecated pubspec method)',
        () async {
          result = await checkProject(
            project: project,
            devDependencies: devDependencies,
            config: config,
            embedConfigInPubspec: true,
          );
          expect(result.exitCode, 0);
        },
      );
    });

    group('fails when there are unused packages', () {
      final devDependencies = {'yaml': hostedAny};

      final config = DepValidatorConfig(ignore: ['yaml']);

      test('', () async {
        result = await checkProject(devDependencies: devDependencies);

        expect(result.exitCode, 1);
        expect(
          result.stderr,
          contains(
            'These packages may be unused, or you may be using assets from these packages:',
          ),
        );
        expect(result.stderr, contains('yaml'));
      });

      test('and import is commented out', () async {
        result = await checkProject(
          devDependencies: devDependencies,
          project: [
            d.dir('lib', [
              d.file(
                'main.dart',
                '// import "package:other_project/other.dart";',
              ),
            ]),
            d.dir('test', [
              d.file('valid.dart', 'import "package:yaml/fake.dart";'),
            ]),
          ],
        );
        expect(result.exitCode, 0);
        expect(result.stdout, contains('No dependency issues found!'));
      });

      test('except when they are ignored', () async {
        result = await checkProject(
          devDependencies: devDependencies,
          config: config,
        );
        expect(result.exitCode, 0);
        expect(result.stdout, contains('No dependency issues found!'));
      });

      test(
        'except when they are ignored (deprecated pubspec method)',
        () async {
          result = await checkProject(
            devDependencies: devDependencies,
            config: config,
            embedConfigInPubspec: true,
          );
          expect(result.exitCode, 0);
          expect(result.stdout, contains('No dependency issues found!'));
        },
      );
    });

    test(
      'warns when the analyzer package is depended on but not used',
      () async {
        result = await checkProject(
          dependencies: {"analyzer": hostedAny},
          project: [
            d.dir('lib', [d.file('main.dart', '')]),
          ],
          config: DepValidatorConfig(ignore: ['analyzer']),
        );
        expect(result.exitCode, 0);
        expect(
          result.stderr,
          contains(
            'You do not need to depend on `analyzer` to run the Dart analyzer.',
          ),
        );
      },
    );

    test('passes when all dependencies are used and valid', () async {
      result = await checkProject(
        dependencies: {"logging": hostedAny, "yaml": hostedAny},
        devDependencies: {"pedantic": hostedAny},
        project: [
          d.dir('lib', [
            d.file(
              'main.dart',
              unindent('''
              import 'package:logging/logging.dart';
              import 'package:yaml/yaml.dart';
              // import 'package:does_not_exist/fake.dart';
            '''),
            ),
            d.file('main.scss', '@import "package:yaml/foo";'),
          ]),
          d.file(
            'analysis_options.yaml',
            'include: package:pedantic/analysis_options.1.8.0.yaml',
          ),
        ],
      );

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No dependency issues found!'));
    });

    test('passes when dependencies not used provide executables', () async {
      result = await checkProject(
        devDependencies: {
          "build_runner": hostedCompatibleWith('2.3.3'),
          'coverage': hostedAny,
          'dart_style': hostedCompatibleWith('2.3.2'),
        },
        project: [
          d.dir('lib', [d.file('main.dart', 'book fake = true;')]),
        ],
      );

      expect(result.exitCode, 0);
      expect(result.stdout, contains('No dependency issues found!'));
    });

    test(
      'fails when dependencies not used provide executables, but are not dev_dependencies',
      () async {
        result = await checkProject(
          dependencies: {
            "build_runner": hostedCompatibleWith('2.3.3'),
            "coverage": hostedAny,
            "dart_style": hostedCompatibleWith('2.3.2'),
          },
          project: [
            d.dir('lib', [d.file('main.dart', 'bool fake = true;')]),
          ],
        );

        expect(result.exitCode, 1);
        expect(
          result.stderr,
          contains(
            'The following packages contain executables, and are only used outside of lib/. These should be downgraded to dev_dependencies',
          ),
        );
      },
    );

    test(
      'passes when dependencies are not imported but provide auto applied builders',
      () async {
        result = await checkProject(
          devDependencies: {
            'build_test': hostedCompatibleWith('2.0.1'),
            'build_vm_compilers': hostedCompatibleWith('1.0.3'),
            'build_web_compilers': hostedCompatibleWith('3.2.7'),
          },
          project: [
            d.dir('lib', [d.file('main.dart', 'book fake = true;')]),
          ],
        );

        expect(result.exitCode, 0);
        expect(result.stdout, contains('No dependency issues found!'));
      },
    );

    test(
      'passes when dependencies are not imported but provide used builders',
      () async {
        result = await checkProject(
          devDependencies: {'yaml': hostedAny},
          project: [
            d.dir('lib', [d.file('main.dart', 'bool fake = true;')]),
            d.file(
              'build.yaml',
              unindent(r'''
              targets:
                $default:
                  builders:
                    yaml|someBuilder:
                      options: {}
          '''),
            ),
          ],
        );

        expect(result.exitCode, 0);
        expect(result.stdout, contains('No dependency issues found!'));
      },
    );

    group('when a dependency is pinned', () {
      final dependencies = {'logging': hostedPinned('1.0.2')};

      final allowPins = DepValidatorConfig(allowPins: true);
      final ignorePackage = DepValidatorConfig(ignore: ['logging']);

      test('fails if pins are not ignored', () async {
        result = await checkProject(dependencies: dependencies);

        expect(result.exitCode, 1);
        expect(
          result.stderr,
          contains('These packages are pinned in pubspec.yaml:\n  * logging'),
        );
      });

      test('should not fails if package is pinned but pins allowed', () async {
        result = await checkProject(
          dependencies: dependencies,
          config: allowPins,
          project: [
            d.dir('lib', [
              d.file('main.dart', 'import "package:logging/logging.dart";'),
            ]),
          ],
        );
        expect(result.exitCode, 0);
        expect(result.stdout, contains('No dependency issues found!'));
      });

      test('ignores infractions if the package is ignored', () async {
        result = await checkProject(
          dependencies: dependencies,
          config: ignorePackage,
        );
        expect(result.exitCode, 0);
        expect(result.stdout, contains('No dependency issues found!'));
      });
    });
  });
}
