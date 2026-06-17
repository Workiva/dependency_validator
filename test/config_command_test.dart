@TestOn('vm')
import 'dart:convert';
import 'dart:io';

import 'package:dependency_validator/src/config_editor.dart';
import 'package:dependency_validator/src/pubspec_config.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'utils.dart';

Future<ProcessResult> runConfigCmd({
  List<String> args = const [],
  DepValidatorConfig? initialConfig,
}) async {
  final pubspec = {
    'name': 'project',
    'environment': {'sdk': '^3.6.0'},
    'dev_dependencies': {
      'dependency_validator': {
        'path': Directory.current.absolute.path.replaceAll(r'\', '/'),
      },
    },
  };
  final dir = d.dir('project', [
    d.file('pubspec.yaml', jsonEncode(pubspec)),
    if (initialConfig != null)
      d.file(
        'dart_dependency_validator.yaml',
        configToYaml(initialConfig),
      ),
  ]);
  await dir.create();
  final path = '${d.sandbox}/project';
  return Process.run(
    'dart',
    ['run', 'dependency_validator', 'config', ...args],
    workingDirectory: path,
  );
}

DepValidatorConfig readResultConfig() {
  final file = File('${d.sandbox}/project/dart_dependency_validator.yaml');
  if (!file.existsSync()) return DepValidatorConfig();
  final content = file.readAsStringSync();
  if (content.trim().isEmpty) return DepValidatorConfig();
  return DepValidatorConfig.fromYaml(content);
}

void main() {
  group('configToYaml', () {
    test('empty config produces empty string', () {
      expect(configToYaml(DepValidatorConfig()), '');
    });

    test('serializes exclude list', () {
      final yaml = configToYaml(DepValidatorConfig(exclude: ['lib/**']));
      expect(yaml, contains('exclude:'));
      expect(yaml, contains("  - 'lib/**'"));
    });

    test('serializes ignore list', () {
      final yaml = configToYaml(DepValidatorConfig(ignore: ['some_package']));
      expect(yaml, contains('ignore:'));
      expect(yaml, contains('  - some_package'));
    });

    test('serializes allow_pins', () {
      final yaml = configToYaml(DepValidatorConfig(allowPins: true));
      expect(yaml, contains('allow_pins: true'));
    });

    test('omits allow_pins when false', () {
      final yaml = configToYaml(DepValidatorConfig(allowPins: false));
      expect(yaml, isNot(contains('allow_pins')));
    });

    test('round-trips through fromYaml', () {
      final original = DepValidatorConfig(
        exclude: ['lib/**', 'test/fixtures/**'],
        ignore: ['yaml', 'path'],
        allowPins: true,
      );
      final yaml = configToYaml(original);
      final parsed = DepValidatorConfig.fromYaml(yaml);
      expect(parsed.exclude, original.exclude);
      expect(parsed.ignore, original.ignore);
      expect(parsed.allowPins, original.allowPins);
    });

    test('round-trips empty config through fromYaml', () {
      final original = DepValidatorConfig();
      final yaml = configToYaml(original);
      expect(yaml, '');
    });
  });

  group('config command', () {
    late ProcessResult result;

    tearDown(() {
      printOnFailure('STDOUT:\n${result.stdout}');
      printOnFailure('STDERR:\n${result.stderr}');
    });

    test('shows usage when no section given', () async {
      result = await runConfigCmd();
      expect(result.exitCode, 64);
      expect(result.stderr, contains('Usage:'));
    });

    test('shows error for unknown section', () async {
      result = await runConfigCmd(args: ['unknown']);
      expect(result.exitCode, 64);
      expect(result.stderr, contains("Unknown config section 'unknown'"));
    });

    group('exclude', () {
      test('list shows empty message when no config', () async {
        result = await runConfigCmd(args: ['exclude', 'list']);
        expect(result.exitCode, 0);
        expect(result.stdout, contains('No excludes configured.'));
      });

      test('list shows current patterns', () async {
        result = await runConfigCmd(
          args: ['exclude', 'list'],
          initialConfig: DepValidatorConfig(exclude: ['lib/**', 'test/**']),
        );
        expect(result.exitCode, 0);
        expect(result.stdout, contains('lib/**'));
        expect(result.stdout, contains('test/**'));
      });

      test('add creates config file and adds pattern', () async {
        result = await runConfigCmd(args: ['exclude', 'add', 'lib/**']);
        expect(result.exitCode, 0);
        expect(result.stdout, contains("Added 'lib/**' to exclude."));
        final config = readResultConfig();
        expect(config.exclude, ['lib/**']);
      });

      test('add appends to existing list', () async {
        result = await runConfigCmd(
          args: ['exclude', 'add', 'test/**'],
          initialConfig: DepValidatorConfig(exclude: ['lib/**']),
        );
        expect(result.exitCode, 0);
        final config = readResultConfig();
        expect(config.exclude, ['lib/**', 'test/**']);
      });

      test('add preserves other config sections', () async {
        result = await runConfigCmd(
          args: ['exclude', 'add', 'test/**'],
          initialConfig: DepValidatorConfig(
            exclude: ['lib/**'],
            ignore: ['yaml'],
            allowPins: true,
          ),
        );
        expect(result.exitCode, 0);
        final config = readResultConfig();
        expect(config.exclude, ['lib/**', 'test/**']);
        expect(config.ignore, ['yaml']);
        expect(config.allowPins, isTrue);
      });

      test('add rejects duplicate', () async {
        result = await runConfigCmd(
          args: ['exclude', 'add', 'lib/**'],
          initialConfig: DepValidatorConfig(exclude: ['lib/**']),
        );
        expect(result.exitCode, 1);
        expect(result.stderr, contains("'lib/**' is already in exclude"));
      });

      test('add shows usage when value missing', () async {
        result = await runConfigCmd(args: ['exclude', 'add']);
        expect(result.exitCode, 64);
        expect(result.stderr, contains('Usage:'));
      });

      test('remove removes pattern', () async {
        result = await runConfigCmd(
          args: ['exclude', 'remove', 'lib/**'],
          initialConfig: DepValidatorConfig(exclude: ['lib/**', 'test/**']),
        );
        expect(result.exitCode, 0);
        expect(result.stdout, contains("Removed 'lib/**' from exclude."));
        final config = readResultConfig();
        expect(config.exclude, ['test/**']);
      });

      test('remove preserves other config sections', () async {
        result = await runConfigCmd(
          args: ['exclude', 'remove', 'lib/**'],
          initialConfig: DepValidatorConfig(
            exclude: ['lib/**'],
            ignore: ['yaml'],
            allowPins: true,
          ),
        );
        expect(result.exitCode, 0);
        final config = readResultConfig();
        expect(config.exclude, isEmpty);
        expect(config.ignore, ['yaml']);
        expect(config.allowPins, isTrue);
      });

      test('remove rejects nonexistent value', () async {
        result = await runConfigCmd(
          args: ['exclude', 'remove', 'nope/**'],
          initialConfig: DepValidatorConfig(exclude: ['lib/**']),
        );
        expect(result.exitCode, 1);
        expect(result.stderr, contains("'nope/**' is not in exclude"));
      });

      test('remove shows usage when value missing', () async {
        result = await runConfigCmd(args: ['exclude', 'remove']);
        expect(result.exitCode, 64);
        expect(result.stderr, contains('Usage:'));
      });

      test('shows usage when no action given', () async {
        result = await runConfigCmd(args: ['exclude']);
        expect(result.exitCode, 64);
        expect(result.stderr, contains('Usage:'));
      });

      test('shows error for unknown action', () async {
        result = await runConfigCmd(args: ['exclude', 'unknown']);
        expect(result.exitCode, 64);
        expect(result.stderr, contains("Unknown action 'unknown'"));
      });
    });

    group('ignore', () {
      test('list shows empty message when no config', () async {
        result = await runConfigCmd(args: ['ignore', 'list']);
        expect(result.exitCode, 0);
        expect(result.stdout, contains('No ignored packages configured.'));
      });

      test('list shows current packages', () async {
        result = await runConfigCmd(
          args: ['ignore', 'list'],
          initialConfig: DepValidatorConfig(ignore: ['yaml', 'path']),
        );
        expect(result.exitCode, 0);
        expect(result.stdout, contains('yaml'));
        expect(result.stdout, contains('path'));
      });

      test('add creates config file and adds package', () async {
        result = await runConfigCmd(args: ['ignore', 'add', 'yaml']);
        expect(result.exitCode, 0);
        expect(result.stdout, contains("Added 'yaml' to ignore."));
        final config = readResultConfig();
        expect(config.ignore, ['yaml']);
      });

      test('add appends to existing list', () async {
        result = await runConfigCmd(
          args: ['ignore', 'add', 'path'],
          initialConfig: DepValidatorConfig(ignore: ['yaml']),
        );
        expect(result.exitCode, 0);
        final config = readResultConfig();
        expect(config.ignore, ['yaml', 'path']);
      });

      test('add preserves other config sections', () async {
        result = await runConfigCmd(
          args: ['ignore', 'add', 'path'],
          initialConfig: DepValidatorConfig(
            exclude: ['lib/**'],
            ignore: ['yaml'],
            allowPins: true,
          ),
        );
        expect(result.exitCode, 0);
        final config = readResultConfig();
        expect(config.exclude, ['lib/**']);
        expect(config.ignore, ['yaml', 'path']);
        expect(config.allowPins, isTrue);
      });

      test('add rejects duplicate', () async {
        result = await runConfigCmd(
          args: ['ignore', 'add', 'yaml'],
          initialConfig: DepValidatorConfig(ignore: ['yaml']),
        );
        expect(result.exitCode, 1);
        expect(result.stderr, contains("'yaml' is already in ignore"));
      });

      test('add shows usage when value missing', () async {
        result = await runConfigCmd(args: ['ignore', 'add']);
        expect(result.exitCode, 64);
        expect(result.stderr, contains('Usage:'));
      });

      test('remove removes package', () async {
        result = await runConfigCmd(
          args: ['ignore', 'remove', 'yaml'],
          initialConfig: DepValidatorConfig(ignore: ['yaml', 'path']),
        );
        expect(result.exitCode, 0);
        expect(result.stdout, contains("Removed 'yaml' from ignore."));
        final config = readResultConfig();
        expect(config.ignore, ['path']);
      });

      test('remove preserves other config sections', () async {
        result = await runConfigCmd(
          args: ['ignore', 'remove', 'yaml'],
          initialConfig: DepValidatorConfig(
            exclude: ['lib/**'],
            ignore: ['yaml'],
            allowPins: true,
          ),
        );
        expect(result.exitCode, 0);
        final config = readResultConfig();
        expect(config.exclude, ['lib/**']);
        expect(config.ignore, isEmpty);
        expect(config.allowPins, isTrue);
      });

      test('remove rejects nonexistent value', () async {
        result = await runConfigCmd(
          args: ['ignore', 'remove', 'nope'],
          initialConfig: DepValidatorConfig(ignore: ['yaml']),
        );
        expect(result.exitCode, 1);
        expect(result.stderr, contains("'nope' is not in ignore"));
      });

      test('remove shows usage when value missing', () async {
        result = await runConfigCmd(args: ['ignore', 'remove']);
        expect(result.exitCode, 64);
        expect(result.stderr, contains('Usage:'));
      });

      test('shows usage when no action given', () async {
        result = await runConfigCmd(args: ['ignore']);
        expect(result.exitCode, 64);
        expect(result.stderr, contains('Usage:'));
      });

      test('shows error for unknown action', () async {
        result = await runConfigCmd(args: ['ignore', 'unknown']);
        expect(result.exitCode, 64);
        expect(result.stderr, contains("Unknown action 'unknown'"));
      });
    });

    group('allow-pins', () {
      test('get returns false by default', () async {
        result = await runConfigCmd(args: ['allow-pins', 'get']);
        expect(result.exitCode, 0);
        expect(result.stdout, contains('false'));
      });

      test('get returns current value', () async {
        result = await runConfigCmd(
          args: ['allow-pins', 'get'],
          initialConfig: DepValidatorConfig(allowPins: true),
        );
        expect(result.exitCode, 0);
        expect(result.stdout, contains('true'));
      });

      test('set to true', () async {
        result = await runConfigCmd(args: ['allow-pins', 'set', 'true']);
        expect(result.exitCode, 0);
        expect(result.stdout, contains('Set allow_pins to true.'));
        final config = readResultConfig();
        expect(config.allowPins, isTrue);
      });

      test('set to false', () async {
        result = await runConfigCmd(
          args: ['allow-pins', 'set', 'false'],
          initialConfig: DepValidatorConfig(allowPins: true),
        );
        expect(result.exitCode, 0);
        expect(result.stdout, contains('Set allow_pins to false.'));
        final config = readResultConfig();
        expect(config.allowPins, isFalse);
      });

      test('set preserves other config sections', () async {
        result = await runConfigCmd(
          args: ['allow-pins', 'set', 'true'],
          initialConfig: DepValidatorConfig(
            exclude: ['lib/**'],
            ignore: ['yaml'],
          ),
        );
        expect(result.exitCode, 0);
        final config = readResultConfig();
        expect(config.exclude, ['lib/**']);
        expect(config.ignore, ['yaml']);
        expect(config.allowPins, isTrue);
      });

      test('set rejects invalid value', () async {
        result = await runConfigCmd(args: ['allow-pins', 'set', 'yes']);
        expect(result.exitCode, 64);
        expect(result.stderr, contains("Invalid value 'yes'"));
      });

      test('set shows usage when value missing', () async {
        result = await runConfigCmd(args: ['allow-pins', 'set']);
        expect(result.exitCode, 64);
        expect(result.stderr, contains('Usage:'));
      });

      test('shows usage when no action given', () async {
        result = await runConfigCmd(args: ['allow-pins']);
        expect(result.exitCode, 64);
        expect(result.stderr, contains('Usage:'));
      });

      test('shows error for unknown action', () async {
        result = await runConfigCmd(args: ['allow-pins', 'unknown']);
        expect(result.exitCode, 64);
        expect(result.stderr, contains("Unknown action 'unknown'"));
      });
    });

    group('with -C flag', () {
      test('operates on specified directory', () async {
        final pubspec = {
          'name': 'project',
          'environment': {'sdk': '^3.6.0'},
          'dev_dependencies': {
            'dependency_validator': {
              'path': Directory.current.absolute.path.replaceAll(r'\', '/'),
            },
          },
        };
        final subDir = d.dir('project', [
          d.file('pubspec.yaml', jsonEncode(pubspec)),
          d.dir('subproject', [
            d.file(
              'dart_dependency_validator.yaml',
              configToYaml(DepValidatorConfig(ignore: ['yaml'])),
            ),
          ]),
        ]);
        await subDir.create();
        final path = '${d.sandbox}/project';
        result = await Process.run(
          'dart',
          [
            'run',
            'dependency_validator',
            'config',
            '-C',
            'subproject',
            'ignore',
            'list',
          ],
          workingDirectory: path,
        );
        expect(result.exitCode, 0);
        expect(result.stdout, contains('yaml'));
      });
    });
  });
}
