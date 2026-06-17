import 'dart:io';

import 'package:path/path.dart' as p;

import 'pubspec_config.dart';

const String configFileName = 'dart_dependency_validator.yaml';

/// Reads the config from [root], returning a default config if the file
/// doesn't exist or is empty.
DepValidatorConfig readConfig(String root) {
  final file = File(p.join(root, configFileName));
  if (!file.existsSync()) return DepValidatorConfig();
  final content = file.readAsStringSync();
  if (content.trim().isEmpty) return DepValidatorConfig();
  return DepValidatorConfig.fromYaml(content);
}

/// Writes [config] as YAML to the config file in [root].
void writeConfig(String root, DepValidatorConfig config) {
  File(p.join(root, configFileName)).writeAsStringSync(configToYaml(config));
}

/// Serializes a [DepValidatorConfig] to YAML, omitting keys with default values.
String configToYaml(DepValidatorConfig config) {
  final buffer = StringBuffer();
  if (config.exclude.isNotEmpty) {
    buffer.writeln('exclude:');
    for (final pattern in config.exclude) {
      buffer.writeln("  - '$pattern'");
    }
  }
  if (config.ignore.isNotEmpty) {
    buffer.writeln('ignore:');
    for (final name in config.ignore) {
      buffer.writeln('  - $name');
    }
  }
  if (config.allowPins) {
    buffer.writeln('allow_pins: true');
  }
  return buffer.toString();
}

/// Runs a config subcommand with the given [args] against the config in [root].
/// Returns an exit code.
int runConfigCommand(List<String> args, String root) {
  if (args.isEmpty) {
    _printConfigUsage();
    return 64;
  }

  switch (args[0]) {
    case 'exclude':
      return _handleListSection(root, 'exclude', args.sublist(1));
    case 'ignore':
      return _handleListSection(root, 'ignore', args.sublist(1));
    case 'allow-pins':
      return _handleAllowPins(root, args.sublist(1));
    default:
      stderr.writeln("Unknown config section '${args[0]}'.");
      _printConfigUsage();
      return 64;
  }
}

void _printConfigUsage() {
  stderr.writeln(
    'Usage: dependency_validator config <section> <action> [value]\n'
    '\n'
    'Sections:\n'
    '  exclude      Glob patterns to exclude from scanning\n'
    '  ignore       Package names to ignore\n'
    '  allow-pins   Whether to allow pinned dependencies\n'
    '\n'
    'Actions for exclude/ignore:\n'
    '  list             List current values\n'
    '  add <value>      Add a value\n'
    '  remove <value>   Remove a value\n'
    '\n'
    'Actions for allow-pins:\n'
    '  get              Get current value\n'
    '  set <true|false> Set value',
  );
}

int _handleListSection(String root, String section, List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dependency_validator config $section <list|add|remove> [value]',
    );
    return 64;
  }

  final config = readConfig(root);
  final isExclude = section == 'exclude';
  final currentList = isExclude ? config.exclude : config.ignore;

  switch (args[0]) {
    case 'list':
      if (currentList.isEmpty) {
        stdout.writeln(
          'No ${isExclude ? 'excludes' : 'ignored packages'} configured.',
        );
      } else {
        for (final item in currentList) {
          stdout.writeln(item);
        }
      }
      return 0;

    case 'add':
      if (args.length < 2) {
        stderr.writeln(
          'Usage: dependency_validator config $section add <value>',
        );
        return 64;
      }
      final value = args[1];
      if (currentList.contains(value)) {
        stderr.writeln("'$value' is already in $section.");
        return 1;
      }
      final newList = [...currentList, value];
      writeConfig(root, _withList(config, section, newList));
      stdout.writeln("Added '$value' to $section.");
      return 0;

    case 'remove':
      if (args.length < 2) {
        stderr.writeln(
          'Usage: dependency_validator config $section remove <value>',
        );
        return 64;
      }
      final value = args[1];
      if (!currentList.contains(value)) {
        stderr.writeln("'$value' is not in $section.");
        return 1;
      }
      final newList = currentList.where((e) => e != value).toList();
      writeConfig(root, _withList(config, section, newList));
      stdout.writeln("Removed '$value' from $section.");
      return 0;

    default:
      stderr.writeln("Unknown action '${args[0]}'.");
      stderr.writeln('Valid actions: list, add, remove');
      return 64;
  }
}

DepValidatorConfig _withList(
  DepValidatorConfig config,
  String section,
  List<String> newList,
) {
  return DepValidatorConfig(
    exclude: section == 'exclude' ? newList : config.exclude,
    ignore: section == 'ignore' ? newList : config.ignore,
    allowPins: config.allowPins,
  );
}

int _handleAllowPins(String root, List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dependency_validator config allow-pins <get|set> [true|false]',
    );
    return 64;
  }

  final config = readConfig(root);

  switch (args[0]) {
    case 'get':
      stdout.writeln(config.allowPins);
      return 0;

    case 'set':
      if (args.length < 2) {
        stderr.writeln(
          'Usage: dependency_validator config allow-pins set <true|false>',
        );
        return 64;
      }
      final value = args[1].toLowerCase();
      if (value != 'true' && value != 'false') {
        stderr.writeln(
          "Invalid value '${args[1]}'. Must be 'true' or 'false'.",
        );
        return 64;
      }
      final newConfig = DepValidatorConfig(
        exclude: config.exclude,
        ignore: config.ignore,
        allowPins: value == 'true',
      );
      writeConfig(root, newConfig);
      stdout.writeln('Set allow_pins to $value.');
      return 0;

    default:
      stderr.writeln("Unknown action '${args[0]}'.");
      stderr.writeln('Valid actions: get, set');
      return 64;
  }
}
