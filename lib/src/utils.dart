import 'dart:io';

import 'package:logging/logging.dart';

final RegExp importExportPackageRegex =
    new RegExp(r'''^(import|export)\s+['"]package:([a-zA-Z_]+)\/.+$''', multiLine: true);

const dependenciesKey = 'dependencies';
const dependencyValidatorPackageName = 'dependency_validator';
const devDependenciesKey = 'dev_dependencies';
const nameKey = 'name';
const transformersKey = 'transformers';

final Logger logger = new Logger('dependency_validator');

String bulletItems(Iterable<String> items) => items.map((l) => '  * $l').join('\n');

Iterable<File> listDartFilesIn(String dirPath) {
  if (!FileSystemEntity.isDirectorySync(dirPath)) return const [];
  return new Directory(dirPath)
      .listSync(recursive: true)
      .where((entity) => entity is File && !entity.path.contains('/packages/') && entity.path.endsWith('.dart'));
}

void logDependencyInfractions(String infraction, Iterable<String> dependencies) {
  final sortedDependencies = dependencies.toList()..sort();
  logger.warning([infraction, bulletItems(sortedDependencies), ''].join('\n'));
}
