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
import 'package:glob/glob.dart';
import 'package:logging/logging.dart';
import 'package:dependency_validator/dependency_validator.dart';
import 'package:path/path.dart' as p;

const String helpArg = 'help';
const String verboseArg = 'verbose';
const String helpMessage = '''Dependency Validator 2.0 is configured statically via the pubspec.yaml
example:
    # in pubspec.yaml
    dependency_validator:
      exclude:
        - 'a_directory/**' # Glob's are supported
        - 'b_directory/some_specific_file.dart'
      ignore:
        - some_package

usage:''';

/// Parses the command-line arguments
final ArgParser argParser = ArgParser()
  ..addFlag(
    helpArg,
    abbr: 'h',
    help: 'Displays this info.',
  )
  ..addFlag(
    verboseArg,
    defaultsTo: false,
    help: 'Display extra information for debugging.',
  );

void showHelpAndExit() {
  Logger.root.shout(helpMessage);
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
  } on FormatException catch (_) {
    showHelpAndExit();
  }

  if (argResults.wasParsed(helpArg) && argResults[helpArg]) {
    showHelpAndExit();
  }

  if (argResults.wasParsed(verboseArg) && argResults[verboseArg]) {
    Logger.root.level = Level.ALL;
  }

  final ignoredPackages = <String>[];

  final excludes = <Glob>[];

  run(
    excludes: excludes,
    ignoredPackages: ignoredPackages,
  );
}
