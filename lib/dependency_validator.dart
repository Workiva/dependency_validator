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

import 'package:yaml/yaml.dart';

import 'src/constants.dart';
import 'src/utils.dart';

export 'src/constants.dart' show commonBinaryPackages;

/// Check for missing, under-promoted, over-promoted, and unused dependencies.
void run({
  List<String> excludedDirs = const [],
  bool fatalDevMissing = true,
  bool fatalMissing = true,
  bool fatalOverPromoted = true,
  bool fatalPins = true,
  bool fatalUnderPromoted = true,
  bool fatalUnused = true,
  List<String> ignoredPackages = const [],
}) {
  // Read and parse the analysis_options.yaml in the current working directory.
  final optionsIncludePackage = getAnalysisOptionsIncludePackage();

  // Read and parse the pubspec.yaml in the current working directory.
  final YamlMap pubspecYaml = loadYaml(File('pubspec.yaml').readAsStringSync());

  // Extract the package name.
  final packageName = pubspecYaml[nameKey];

  logger.info('Validating dependencies for $packageName\n');

  checkPubspecYamlForPins(pubspecYaml, ignoredPackages: ignoredPackages, fatal: fatalPins);

  // Extract the package names from the `dependencies` section.
  final deps =
      pubspecYaml.containsKey(dependenciesKey) ? Set<String>.from(pubspecYaml[dependenciesKey].keys) : <String>{};
  logger.fine('dependencies:\n${bulletItems(deps)}\n');

  // Extract the package names from the `dev_dependencies` section.
  final devDeps =
      pubspecYaml.containsKey(devDependenciesKey) ? Set<String>.from(pubspecYaml[devDependenciesKey].keys) : <String>{};
  logger.fine('dev_dependencies:\n'
      '${bulletItems(devDeps)}\n');

  // Extract the package names from the `transformers` section.
  final Iterable transformerEntries = pubspecYaml[transformersKey];
  final packagesUsedViaTransformers = pubspecYaml.containsKey(transformersKey)
      ? Set<String>.from(transformerEntries
          .map<String>((value) => value is YamlMap ? value.keys.first : value)
          .map((value) => value.replaceFirst(RegExp(r'/.*'), '')))
      : <String>{};
  logger.fine('transformers:\n'
      '${bulletItems(packagesUsedViaTransformers)}\n');

  // Recursively list all Dart and Scss files in lib/
  final publicDartFiles = <File>[]
    ..addAll(listDartFilesIn('lib/', excludedDirs))
    ..addAll(listDartFilesIn('bin/', excludedDirs));

  final publicScssFiles = <File>[]
    ..addAll(listScssFilesIn('lib/', excludedDirs))
    ..addAll(listScssFilesIn('bin/', excludedDirs));

  logger
    ..fine('public facing dart files:\n'
        '${bulletItems(publicDartFiles.map((f) => f.path))}\n')
    ..fine('public facing scss files:\n'
        '${bulletItems(publicScssFiles.map((f) => f.path))}\n');

  // Read each file in lib/ and parse the package names from every import and
  // export directive.
  final packagesUsedInPublicFiles = <String>{};
  for (final file in publicDartFiles) {
    final matches = importExportDartPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedInPublicFiles.add(match.group(2));
    }
  }
  for (final file in publicScssFiles) {
    final matches = importScssPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedInPublicFiles.add(match.group(1));
    }
  }

  logger.fine('packages used in public facing files:\n'
      '${bulletItems(packagesUsedInPublicFiles)}\n');

  // Recursively list all Dart files in known directories other than lib/
  final nonLibDartFiles = <File>[]
    ..addAll(listDartFilesIn('example/', excludedDirs))
    ..addAll(listDartFilesIn('test/', excludedDirs))
    ..addAll(listDartFilesIn('tool/', excludedDirs))
    ..addAll(listDartFilesIn('web/', excludedDirs));
  final nonLibScssFiles = <File>[]
    ..addAll(listScssFilesIn('example/', excludedDirs))
    ..addAll(listScssFilesIn('test/', excludedDirs))
    ..addAll(listScssFilesIn('tool/', excludedDirs))
    ..addAll(listScssFilesIn('web/', excludedDirs));

  logger
    ..fine('non-lib dart files:\n'
        '${bulletItems(nonLibDartFiles.map((f) => f.path))}\n')
    ..fine('non-lib scss files:\n'
        '${bulletItems(nonLibScssFiles.map((f) => f.path))}\n');

  // Read each file outside lib/ and parse the package names from every
  // import and export directive.
  final packagesUsedOutsideLib = <String>{
    if (optionsIncludePackage != null) optionsIncludePackage,
  };
  for (final file in nonLibDartFiles) {
    final matches = importExportDartPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedOutsideLib.add(match.group(2));
    }
  }
  for (final file in nonLibScssFiles) {
    final matches = importScssPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedOutsideLib.add(match.group(1));
    }
  }

  logger.fine('packages used outside lib:\n'
      '${bulletItems(packagesUsedOutsideLib)}\n');

  // Packages that are used in lib/ but are not dependencies.
  final missingDependencies =
      // Start with packages used in lib/
      packagesUsedInPublicFiles
          // Remove all explicitly declared dependencies
          .difference(deps)
          .difference(devDeps)
            // Ignore self-imports - packages have implicit access to themselves.
            ..remove(packageName)
            // Ignore known missing packages.
            ..removeAll(ignoredPackages);

  if (missingDependencies.isNotEmpty) {
    logDependencyInfractions(
      'These packages are used in lib/ but are not dependencies:',
      missingDependencies,
    );
    if (fatalMissing) exitCode = 1;
  }

  // Packages that are used outside lib/ but are not dev_dependencies.
  final missingDevDependencies =
      // Start with packages _only_ used outside lib/
      packagesUsedOutsideLib
          .difference(packagesUsedInPublicFiles)
          // Remove all explicitly declared dependencies
          .difference(devDeps)
          .difference(deps)
            // Ignore self-imports - packages have implicit access to themselves.
            ..remove(packageName)
            // Ignore known missing packages.
            ..removeAll(ignoredPackages);

  if (missingDevDependencies.isNotEmpty) {
    logDependencyInfractions(
      'These packages are used outside lib/ but are not dev_dependencies:',
      missingDevDependencies,
    );
    if (fatalDevMissing) exitCode = 1;
  }

  // Packages that are not used in lib/, but are used elsewhere, that are
  // dependencies when they should be dev_dependencies.
  final overPromotedDependencies =
      // Start with dependencies that are not used in lib/
      (deps
          .difference(packagesUsedInPublicFiles)
          // Intersect with deps that are used outside lib/ (excludes unused deps)
          .intersection(packagesUsedOutsideLib))
        // Ignore known over-promoted packages.
        ..removeAll(ignoredPackages);

  if (overPromotedDependencies.isNotEmpty) {
    logDependencyInfractions(
      'These packages are only used outside lib/ and should be downgraded to dev_dependencies:',
      overPromotedDependencies,
    );
    if (fatalOverPromoted) exitCode = 1;
  }

  // Packages that are used in lib/, but are dev_dependencies.
  final underPromotedDependencies =
      // Start with dev_dependencies that are used in lib/
      devDeps.intersection(packagesUsedInPublicFiles)
        // Ignore known under-promoted packages
        ..removeAll(ignoredPackages);

  if (underPromotedDependencies.isNotEmpty) {
    logDependencyInfractions(
      'These packages are used in lib/ and should be promoted to actual dependencies:',
      underPromotedDependencies,
    );
    if (fatalUnderPromoted) exitCode = 1;
  }

  // Packages that are not used anywhere but are dependencies.
  final unusedDependencies =
      // Start with all explicitly declared dependencies
      deps
          .union(devDeps)
          // Remove all deps that were used in Dart code somewhere in this package
          .difference(packagesUsedInPublicFiles)
          .difference(packagesUsedOutsideLib)
          // Remove all deps being used for their transformer(s)
          .difference(packagesUsedViaTransformers)
            // Remove this package, since we know they're using our executable
            ..remove(dependencyValidatorPackageName);

  if (unusedDependencies.contains('analyzer')) {
    logger.warning(
      'You do not need to depend on `analyzer` to run the Dart analyzer.\n'
      'Instead, just run the `dartanalyzer` executable that is bundled with the Dart SDK.',
    );
  }

  // Ignore known unused packages
  unusedDependencies.removeAll(ignoredPackages);

  if (unusedDependencies.isNotEmpty) {
    logDependencyInfractions(
      'These packages may be unused, or you may be using executables or assets from these packages:',
      unusedDependencies,
    );

    if (fatalUnused) exitCode = 1;
  }

  if (exitCode == 0) {
    logger.info('No fatal infractions found, $packageName is good to go!');
  }
}

/// Checks for dependency pins.
///
/// A pin is any dependency which does not automatically consume the next
/// patch or minor release.
///
/// Examples of dependencies that should cause a failure:
///
/// package: 1.2.3            # blocks minor/patch releases
/// package: ">=0.0.1 <0.0.2" # blocks minor/patch releases
/// package: ">=0.1.1 <0.1.2" # blocks minor/patch releases
/// package: ">=1.2.2 <1.2.3" # blocks minor/patch releases
/// package: ">=1.2.2 <1.3.0" # blocks minor releases
/// package: ">=1.2.2 <=2.0.0 # blocks minor/patch releases
///
/// Example of something that should NOT cause a failure
///
/// package: ^1.2.3
/// package: ">=1.2.3 <2.0.0"
void checkPubspecYamlForPins(
  YamlMap pubspecYaml, {
  List<String> ignoredPackages = const [],
  bool fatal = true,
}) {
  final List<String> infractions = [];
  if (pubspecYaml.containsKey(dependenciesKey)) {
    infractions.addAll(
      getDependenciesWithPins(pubspecYaml[dependenciesKey], ignoredPackages: ignoredPackages),
    );
  }

  if (pubspecYaml.containsKey(devDependenciesKey)) {
    infractions.addAll(
      getDependenciesWithPins(pubspecYaml[devDependenciesKey], ignoredPackages: ignoredPackages),
    );
  }

  if (infractions.isNotEmpty) {
    logDependencyInfractions('These packages are pinned in pubspec.yaml:', infractions);
    if (fatal) exitCode = 1;
  }
}
