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

import 'dart:io' show exit, stderr, stdout;

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:dependency_validator/dependency_validator.dart';

const String helpArg = 'help';
const String verboseArg = 'verbose';
const String ignoreArg = 'ignore';
const String ignoreCommonBinariesArg = 'ignore-common-binaries';

const String excludeDirArg = 'exclude-dir';

const String fatalPinsArg = 'fatal-pins';

const String fatalMissingArg = 'fatal-missing';
const String fatalDevMissingArg = 'fatal-dev-missing';

const String fatalUnderPromotedArg = 'fatal-under-promoted';
const String fatalOverPromotedArg = 'fatal-over-promoted';

const String fatalUnusedArg = 'fatal-unused';

/// Parses the command-line arguments
final ArgParser argParser = new ArgParser()
  ..addFlag(
    helpArg,
    abbr: 'h',
    help: 'Displays this info.',
  )
  ..addFlag(
    verboseArg,
    defaultsTo: false,
    help: 'Display extra information for debugging.',
  )
  ..addOption(
    ignoreArg,
    abbr: 'i',
    allowMultiple: true,
    help: 'Comma-delimited list of packages to ignore from validation.',
    splitCommas: true,
  )
  ..addFlag(ignoreCommonBinariesArg,
      defaultsTo: true,
      help: 'Whether to ignore the following packages that are typically used only for their binaries:\n'
          '${commonBinaryPackages.map((packageName) => '- $packageName').join('\n')}')
  ..addOption(
    excludeDirArg,
    abbr: 'x',
    allowMultiple: true,
    help: 'Comma-delimited list of directories to exclude from validation.',
    splitCommas: true,
  )
  ..addFlag(
    fatalPinsArg,
    defaultsTo: true,
    help: 'Whether to fail on dependency pins.',
  )
  ..addFlag(
    fatalUnderPromotedArg,
    help: 'Whether to fail on dependencies that are in `dev_dependencies` that should be in `dependencies`.',
    defaultsTo: true,
  )
  ..addFlag(
    fatalOverPromotedArg,
    defaultsTo: true,
    help: 'Whether to fail on dependencies that are in `dependencies` that should be in `dev_dependencies`.',
  )
  ..addFlag(
    fatalMissingArg,
    defaultsTo: true,
    help: 'Whether to fail on dependencies that are missing from `dependencies`.',
  )
  ..addFlag(
    fatalDevMissingArg,
    defaultsTo: true,
    help: 'Whether to fail on dependencies that are missing from `dev_dependencies`.',
  )
  ..addFlag(
    fatalUnusedArg,
    defaultsTo: true,
    help: 'Whether to fail on dependencies in the `pubspec.yaml` that are never used in any of:\n'
        '- bin/\n'
        '- lib/\n'
        '- examples/\n'
        '- test/\n'
        '- tool/\n'
        '- web/\n',
  );

void showHelpAndExit() {
  Logger.root.shout(argParser.usage);
  exit(0);
}

void main(List<String> args) {
  Logger.root.onRecord
      .where((record) => record.level < Level.WARNING)
      .map((record) => record.message)
      .listen(stdout.writeln);
  Logger.root.onRecord
      .where((record) => record.level >= Level.WARNING)
      .map((record) => record.message)
      .listen(stderr.writeln);

  ArgResults argResults;
  try {
    argResults = argParser.parse(args);
  } catch (e) {
    showHelpAndExit();
  }

  if (argResults.wasParsed(helpArg) && argResults[helpArg]) {
    showHelpAndExit();
  }

  if (argResults.wasParsed(verboseArg) && argResults[verboseArg]) {
    Logger.root.level = Level.ALL;
  }

  final fatalUnderPromoted = argResults[fatalUnderPromotedArg] ?? true;
  final fatalOverPromoted = argResults[fatalOverPromotedArg] ?? true;
  final fatalMissing = argResults[fatalMissingArg] ?? true;
  final fatalDevMissing = argResults[fatalDevMissingArg] ?? true;
  final fatalUnused = argResults[fatalUnusedArg] ?? true;
  final fatalPins = argResults[fatalPinsArg] ?? true;

  List<String> ignoredPackages;

  if (argResults.wasParsed('ignore')) {
    ignoredPackages = argResults['ignore'];
  } else {
    ignoredPackages = <String>[];
  }

  final ignoreCommonBinaries = argResults[ignoreCommonBinariesArg] ?? true;
  if (ignoreCommonBinaries) {
    ignoredPackages.addAll(commonBinaryPackages);
  }

  List<String> excludedDirs;

  if (argResults.wasParsed('exclude-dir')) {
    excludedDirs = argResults['exclude-dir'];
  } else {
    excludedDirs = const <String>[];
  }

  run(
    excludedDirs: excludedDirs,
    fatalDevMissing: fatalDevMissing,
    fatalMissing: fatalMissing,
    fatalOverPromoted: fatalOverPromoted,
    fatalPins: fatalPins,
    fatalUnused: fatalUnused,
    fatalUnderPromoted: fatalUnderPromoted,
    ignoredPackages: ignoredPackages,
  );
}
