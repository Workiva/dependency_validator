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

import 'package:glob/glob.dart';
import 'package:io/ansi.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

import 'constants.dart';

/// Logger instance to use within dependency_validator.
final Logger logger = Logger('dependency_validator');

/// Returns a multi-line string with all [items] in a bulleted list format.
String bulletItems(Iterable<String> items) =>
    items.map((l) => '  * $l').join('\n');

/// Returns the name of the package referenced in the `include:` directive in an
/// analysis_options.yaml file, or null if there is not one.
String? getAnalysisOptionsIncludePackage({String? path}) {
  final optionsFile = File(p.join(path ?? p.current, 'analysis_options.yaml'));
  if (!optionsFile.existsSync()) return null;

  final YamlMap? analysisOptions = loadYaml(optionsFile.readAsStringSync());
  if (analysisOptions == null) return null;

  final String? include = analysisOptions['include'];
  if (include == null || !include.startsWith('package:')) return null;

  return Uri.parse(include).pathSegments.first;
}

/// Returns an iterable of all Dart files (files ending in .dart) in the given
/// [dirPath] excluding any files matched by any glob in [excludes].
///
/// This also excludes Dart files that are in a hidden directory, like
/// `.dart_tool`.
Iterable<File> listDartFilesIn(String dirPath, List<Glob> excludes) =>
    listFilesWithExtensionIn(dirPath, excludes, 'dart');

/// Returns an iterable of all Scss files (files ending in .scss) in the given
/// [dirPath] excluding any files matched by any glob in [excludes].
///
/// This also excludes Dart files that are in a hidden directory, like
/// `.dart_tool`.
Iterable<File> listScssFilesIn(String dirPath, List<Glob> excludes) =>
    listFilesWithExtensionIn(dirPath, excludes, 'scss');

/// Returns an iterable of all Less files (files ending in .less) in the given
/// [dirPath] excluding any sub-directories specified in [excludedDirs].
///
/// This also excludes Less files that are in a `packages/` subdirectory.
Iterable<File> listLessFilesIn(String dirPath, List<Glob> excludedDirs) =>
    listFilesWithExtensionIn(dirPath, excludedDirs, 'less');

/// Returns an iterable of all files ending in .[extension] in the given
/// [dirPath] excluding any files matched by any glob in [excludes].
///
/// This also excludes Dart files that are in a hidden directory, like
/// `.dart_tool`.
Iterable<File> listFilesWithExtensionIn(
  String dirPath,
  List<Glob> excludes,
  String ext,
) {
  if (!FileSystemEntity.isDirectorySync(dirPath)) return [];

  return Directory(dirPath)
      .listSync(recursive: true)
      .whereType<File>()
      // Skip files in hidden directories (e.g. `.dart_tool/`)
      .where(
        (file) => !p.split(file.path).any((d) => d != '.' && d.startsWith('.')),
      )
      // Filter by the given file extension
      .where((file) => p.extension(file.path) == '.$ext')
      // Skip any files that match one of the given exclude globs
      .where((file) => excludes.every((glob) => !glob.matches(file.path)));
}

/// Logs the given [message] at [level] and lists all of the given [dependencies].
void log(Level level, String message, Iterable<String> dependencies) {
  final sortedDependencies = dependencies.toList()..sort();
  var combined = [message, bulletItems(sortedDependencies)].join('\n');
  if (level >= Level.SEVERE) {
    combined = red.wrap(combined)!;
  } else if (level >= Level.WARNING) {
    combined = yellow.wrap(combined)!;
  }
  logger.log(level, combined);
}

/// Logs the given [message] at [level] and lists the intersection of [dependenciesA]
/// and [dependenciesB] if there is one.
void logIntersection(
  Level level,
  String message,
  Set<String> dependenciesA,
  Set<String> dependenciesB,
) {
  final intersection = dependenciesA.intersection(dependenciesB);
  if (intersection.isNotEmpty) {
    log(level, message, intersection);
  }
}

/// Lists the packages with infractions
List<String> getDependenciesWithPins(
  Map<String, Dependency> dependencies, {
  List<String> ignoredPackages = const [],
}) {
  final List<String> infractions = [];
  for (String packageName in dependencies.keys) {
    if (ignoredPackages.contains(packageName)) {
      continue;
    }

    final packageMeta = dependencies[packageName];

    if (packageMeta is HostedDependency) {
      final evaluation = inspectVersionForPins(packageMeta.version);

      if (evaluation.isPin) {
        infractions.add(
          '$packageName: ${packageMeta.version} -- ${evaluation.message}',
        );
      }
    } else {
      // This feature only works for versions, not git refs or paths.
      continue;
    }
  }

  return infractions;
}

/// Returns the reason a version is a pin or null if it's not.
DependencyPinEvaluation inspectVersionForPins(VersionConstraint constraint) {
  if (constraint.isAny) {
    return DependencyPinEvaluation.notAPin;
  }

  if (constraint is Version) {
    return DependencyPinEvaluation.directPin;
  }

  if (constraint is VersionRange) {
    if (constraint.includeMax) {
      return DependencyPinEvaluation.inclusiveMax;
    }

    final Version? max = constraint.max;

    if (max == null) {
      return DependencyPinEvaluation.notAPin;
    }

    if (max.build.isNotEmpty || (max.isPreRelease && !max.isFirstPreRelease)) {
      return DependencyPinEvaluation.buildOrPrerelease;
    }

    if (max.major > 0) {
      if (max.patch > 0) {
        return DependencyPinEvaluation.blocksPatchReleases;
      }

      if (max.minor > 0) {
        return DependencyPinEvaluation.blocksMinorBumps;
      }
    } else {
      if (max.patch > 0) {
        return DependencyPinEvaluation.blocksMinorBumps;
      }
    }

    return DependencyPinEvaluation.notAPin;
  }

  return DependencyPinEvaluation.emptyPin;
}

/// Utilities for Pubspec objects.
extension PubspecUtils on Pubspec {
  /// Whether this package is the root of a Pub Workspace.
  bool get isWorkspaceRoot => workspace != null;

  /// Whether this package is a sub-package in a Pub Workspace.
  bool get isInWorkspace => resolution == 'workspace';
}

/// Makes a glob object for the given path.
///
/// This function removes `./` paths and replaces all `\` with `/`.
Glob makeGlob(String path) =>
    Glob(p.posix.normalize(path.replaceAll(r'\', '/')));
