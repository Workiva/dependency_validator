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

import 'dart:io' show stderr, stdout;

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:dependency_validator/dependency_validator.dart';

final ArgParser argParser = new ArgParser()
  ..addFlag('verbose', defaultsTo: false)
  ..addOption('ignore', abbr: 'i', allowMultiple: true, splitCommas: true)
  ..addOption('exclude-dir', abbr: 'x', allowMultiple: true, splitCommas: true)
  ..addFlag('fatal-pins', defaultsTo: true)
  ..addFlag('fatal-under-promoted', defaultsTo: true)
  ..addFlag('fatal-over-promoted', defaultsTo: true)
  ..addFlag('fatal-missing', defaultsTo: true)
  ..addFlag('fatal-dev-missing', defaultsTo: true)
  ..addFlag('fatal-unused', defaultsTo: true);

void main(List<String> args) {
  final argResults = argParser.parse(args);

  if (argResults.wasParsed('verbose') && argResults['verbose']) {
    Logger.root.level = Level.ALL;
  }

  final fatalUnderPromoted = argResults['fatal-under-promoted'] ?? true;
  final fatalOverPromoted = argResults['fatal-over-promoted'] ?? true;
  final fatalMissing = argResults['fatal-missing'] ?? true;
  final fatalDevMissing = argResults['fatal-dev-missing'] ?? true;
  final fatalUnused = argResults['fatal-unused'] ?? true;
  final fatalPins = argResults['fatal-pins'] ?? true;

  List<String> ignoredPackages;

  if (argResults.wasParsed('ignore')) {
    ignoredPackages = argResults['ignore'];
  } else {
    ignoredPackages = const <String>[];
  }

  List<String> excludedDirs;

  if (argResults.wasParsed('exclude-dir')) {
    excludedDirs = argResults['exclude-dir'];
  } else {
    excludedDirs = const <String>[];
  }

  Logger.root.onRecord
      .where((record) => record.level < Level.WARNING)
      .map((record) => record.message)
      .listen(stdout.writeln);
  Logger.root.onRecord
      .where((record) => record.level >= Level.WARNING)
      .map((record) => record.message)
      .listen(stderr.writeln);

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
