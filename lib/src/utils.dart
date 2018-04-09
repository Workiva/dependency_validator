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

/// Regex used to detect all import and export directives.
final RegExp importExportPackageRegex =
    new RegExp(r'''\b(import|export)\s+['"]{1,3}package:([a-zA-Z0-9_]+)\/[^;]+''', multiLine: true);

/// String key in pubspec.yaml for the dependencies map.
const String dependenciesKey = 'dependencies';

/// Name of this package.
const String dependencyValidatorPackageName = 'dependency_validator';

/// String key in pubspec.yaml for the dev_dependencies map.
const String devDependenciesKey = 'dev_dependencies';

/// String key in pubspec.yaml for the package name.
const String nameKey = 'name';

/// String key in pubspec.yaml for the transformers map.
const String transformersKey = 'transformers';

/// Logger instance to use within dependency_validator.
final Logger logger = new Logger('dependency_validator');

/// Returns a multi-line string with all [items] in a bulleted list format.
String bulletItems(Iterable<String> items) => items.map((l) => '  * $l').join('\n');

/// Returns an iterable of all Dart files (files ending in .dart) in the given
/// [dirPath] excluding any sub-directories specified in [excludedDirs].
///
/// This also excludes Dart files that are in a `packages/` subdirectory.
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

/// Logs a warning with the given [infraction] and lists all of the given
/// [dependencies] under that infraction.
void logDependencyInfractions(String infraction, Iterable<String> dependencies) {
  final sortedDependencies = dependencies.toList()..sort();
  logger.warning([infraction, bulletItems(sortedDependencies), ''].join('\n'));
}
