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
import 'package:yaml/yaml.dart';

export 'package:yaml/yaml.dart' show loadYaml;

final RegExp importExportPackageRegex =
    new RegExp(r'''^(import|export)\s+['"]package:([a-zA-Z_]+)\/.+$''', multiLine: true);

final Logger logger = new Logger('dependency_validator');

String bulletItems(Iterable<String> items) => items.map((l) => '  * $l').join('\n');

Iterable<File> listDartFilesIn(String dirPath) {
  if (!FileSystemEntity.isDirectorySync(dirPath)) return const [];

  final list = new Directory(dirPath).listSync(recursive: true)
    ..retainWhere((entity) => entity is File && !entity.path.contains('/packages/') && entity.path.endsWith('.dart'));

  return new List<File>.from(list);
}

void logDependencyInfractions(String infraction, Iterable<String> dependencies) {
  final sortedDependencies = dependencies.toList()..sort();
  logger.warning([infraction, bulletItems(sortedDependencies), ''].join('\n'));
}

class PubspecYaml {
  final dynamic _yamlMap;
  static const _dependenciesKey = 'dependencies';
  static const _dependencyValidatorPackageName = 'dependency_validator';
  static const _devDependenciesKey = 'dev_dependencies';
  static const _nameKey = 'name';
  static const _transformersKey = 'transformers';
  static const _pubspecPath = 'pubspec.yaml';

  PubspecYaml() : _yamlMap = loadYaml(new File(_pubspecPath).readAsStringSync());

  String get name => _yamlMap[_nameKey] as String;

  Set<String> get dependencies =>
      ((_yamlMap[_dependenciesKey] as YamlMap ?? const <dynamic, dynamic>{}).keys as Iterable<String>).toSet();

  Set<String> get devDependencies =>
      ((_yamlMap[_devDependenciesKey] as YamlMap ?? const <dynamic, dynamic>{}).keys as Iterable<String>).toSet()
        // Remove this package, since we know they're using our executable
        ..remove(_dependencyValidatorPackageName);

  Set<String> get packagesUsedViaTransformers {
    final transformerEntries = _yamlMap[_transformersKey] as Iterable<Object>;

    if (transformerEntries == null || transformerEntries.isEmpty) return new Set<String>();

    return transformerEntries
        .map<String>((value) {
          if (value is Map<String, dynamic>) return value.keys.first;
          if (value is String) return value;
        })
        .map<String>((value) => value.replaceFirst(new RegExp(r'\/.*'), ''))
        .toSet();
  }
}
