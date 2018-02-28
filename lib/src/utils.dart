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

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final RegExp importExportPackageRegex =
    new RegExp(r'''^\s*(import|export)\s+['"]{1,3}package:([a-zA-Z0-9_]+)\/.+$''', multiLine: true);

const dependenciesKey = 'dependencies';
const dependencyValidatorPackageName = 'dependency_validator';
const devDependenciesKey = 'dev_dependencies';
const nameKey = 'name';
const transformersKey = 'transformers';

final Logger logger = new Logger('dependency_validator');

String bulletItems(Iterable<String> items) => items.map((l) => '  * $l').join('\n');

Iterable<File> listDartFilesIn(String dirPath, List<String> excludedDirs) {
  if (!FileSystemEntity.isDirectorySync(dirPath)) return const [];

  return new Directory(dirPath).listSync(recursive: true).where((entity) {
    if (entity is! File) return false;
    if (p.split(entity.path).contains('packages')) return false;
    if (p.extension(entity.path) != ('.dart')) return false;
    if (excludedDirs.any((dir) => p.isWithin(dir, entity.path))) return false;

    return true;
  });
}

void logDependencyInfractions(String infraction, Iterable<String> dependencies) {
  final sortedDependencies = dependencies.toList()..sort();
  logger.warning([infraction, bulletItems(sortedDependencies), ''].join('\n'));
}
