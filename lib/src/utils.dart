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

import 'package:pub_semver/pub_semver.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Regex used to detect all Dart import and export directives.
final RegExp importExportDartPackageRegex =
    new RegExp(r'''\b(import|export)\s+['"]{1,3}package:([a-zA-Z0-9_]+)\/[^;]+''', multiLine: true);

/// Regex used to detect all Sass import directives.
final RegExp importScssPackageRegex = new RegExp(r'''\@import\s+['"]{1,3}package:\s*([a-zA-Z0-9_]+)\/[^;]+''');

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
Iterable<File> listDartFilesIn(String dirPath, List<String> excludedDirs) =>
    listFilesWithExtensionIn(dirPath, excludedDirs, 'dart');

/// Returns an iterable of all Scss files (files ending in .scss) in the given
/// [dirPath] excluding any sub-directories specified in [excludedDirs].
///
/// This also excludes Scss files that are in a `packages/` subdirectory.
Iterable<File> listScssFilesIn(String dirPath, List<String> excludedDirs) =>
    listFilesWithExtensionIn(dirPath, excludedDirs, 'scss');

/// Returns an iterable of all files ending in .[type] in the given
/// [dirPath] excluding any sub-directories specified in [excludedDirs].
///
/// This also excludes files that are in a `packages/` subdirectory.
Iterable<File> listFilesWithExtensionIn(String dirPath, List<String> excludedDirs, String extension) {
  if (!FileSystemEntity.isDirectorySync(dirPath)) return const [];

  return new Directory(dirPath).listSync(recursive: true).where((entity) {
    if (entity is! File) return false;
    if (p.split(entity.path).contains('packages')) return false;
    if (p.extension(entity.path) != ('.$extension')) return false;
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

/// Lists the packages with infractions
List<String> getDependenciesWithPins(Map dependencies) {
  final List<String> infractions = [];
  for (String packageName in dependencies.keys) {
    String version;
    if (dependencies[packageName] is String) {
      version = dependencies[packageName];
    } else {
      final Map packageMeta = dependencies[packageName];
      if (packageMeta.containsKey('version')) {
        version = packageMeta['version'];
      } else {
        // This feature only works for versions, not git refs or paths.
        break;
      }
    }

    if (doesVersionPinDependency(version)) {
      infractions.add(packageName);
    }
  }

  return infractions;
}

/// Returns whether the version restricts patch or minor upgrades.
bool doesVersionPinDependency(String rawVersion) {
  final String version = rawVersion.replaceAll('"', '').replaceAll("'", '');

  final VersionConstraint constraint = new VersionConstraint.parse(version);

  // No max set = no pin
  if (constraint.isAny) {
    return false;
  }

  // Direct pin
  if (constraint is Version) {
    return true;
  }

  if (constraint is VersionRange) {
    // Defined maximum bound is a pin
    if (constraint.includeMax) {
      return true;
    }

    final Version max = constraint.max;

    // Builds and prereleases also block patch and minor bumps
    if (max.build.isNotEmpty ||
        // First preRelease here is okay because the upper bound is not inclusive
        (max.isPreRelease && !max.isFirstPreRelease)) {
      return true;
    }

    // Check legal upper bound doesn't block minor bumps
    if (max.major == 0) {
      if (max.minor == 0) {
        return true; // 0.0.x
      }
      return max.patch != 0; // 0.x.0
    }
    return max.minor + max.patch > 0; // x.0.0
  }

  // Empty version constraints are pins
  return true;
}
