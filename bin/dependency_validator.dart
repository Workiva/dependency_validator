import 'dart:io' show stderr, stdout;

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:dependency_validator/dependency_validator.dart';

final ArgParser argParser = new ArgParser()
  ..addFlag('verbose', defaultsTo: false)
  ..addOption('ignore', abbr: 'i', allowMultiple: true, splitCommas: true);

void main(List<String> args) {
  final argResults = argParser.parse(args);

  if (argResults.wasParsed('verbose') && argResults['verbose']) {
    Logger.root.level = Level.ALL;
  }

  List<String> ignoredPackages;

  if (argResults.wasParsed('ignore')) {
    ignoredPackages = argResults['ignore'];
  } else {
    ignoredPackages = const <String>[];
  }

  Logger.root.onRecord
      .where((record) => record.level < Level.WARNING)
      .map((record) => record.message)
      .listen(stdout.writeln);
  Logger.root.onRecord
      .where((record) => record.level >= Level.WARNING)
      .map((record) => record.message)
      .listen(stderr.writeln);
  run(ignoredPackages: ignoredPackages);
}
