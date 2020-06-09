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
import 'package:logging/logging.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'src/constants.dart';
import 'src/pubspec_config.dart';
import 'src/utils.dart';

export 'src/constants.dart' show commonBinaryPackages;

/// Check for missing, under-promoted, over-promoted, and unused dependencies.
Future<Null> run() async {
  if (!File('pubspec.yaml').existsSync()) {
    logger.shout('pubspec.yaml not found');
    exit(1);
  }
  if (!File('.dart_tool/package_config.json').existsSync()) {
    logger.shout('No .dart_tool/package_config.json file found, please run "pub get" first.');
    exit(1);
  }

  final config = PubspecDepValidatorConfig.fromYaml(File('pubspec.yaml').readAsStringSync()).dependencyValidator;
  final configExcludes = config?.exclude
      ?.map((s) {
        try {
          return Glob(s);
        } catch (_, __) {
          logger.shout('invalid glob syntax: "$s"');
          return null;
        }
      })
      ?.where((g) => g != null)
      ?.toList();
  final excludes = configExcludes ?? <Glob>[];
  logger.fine('excludes:\n${bulletItems(excludes.map((g) => g.pattern))}\n');
  final ignoredPackages = <String>[...commonBinaryPackages, ...config?.ignore ?? []];
  logger.fine('ignored packages:\n${bulletItems(ignoredPackages)}\n');

  // Read and parse the analysis_options.yaml in the current working directory.
  final optionsIncludePackage = getAnalysisOptionsIncludePackage();

  // Read and parse the pubspec.yaml in the current working directory.
  final YamlMap pubspecYaml = loadYaml(File('pubspec.yaml').readAsStringSync());

  // Extract the package name.
  final packageName = pubspecYaml[nameKey];

  logger.info('Validating dependencies for $packageName\n');

  // Find packages that provide executables.
  final packagesWithExecutables = Set<String>();
  final packageConfig = await findPackageConfig(Directory.current);
  for (final package in packageConfig.packages) {
    final binDir = Directory(p.join(package.root.path, 'bin'));
    hasDartFiles() => binDir.listSync().where((entity) => entity.path.endsWith('.dart')).isNotEmpty;
    if (binDir.existsSync() && hasDartFiles()) {
      packagesWithExecutables.add(package.name);
    }
  }

  checkPubspecYamlForPins(pubspecYaml, ignoredPackages: ignoredPackages);

  // Extract the package names from the `dependencies` section.
  final deps =
      pubspecYaml.containsKey(dependenciesKey) ? Set<String>.from(pubspecYaml[dependenciesKey].keys) : <String>{};
  logger.fine('dependencies:\n${bulletItems(deps)}\n');

  // Extract the package names from the `dev_dependencies` section.
  final devDeps =
      pubspecYaml.containsKey(devDependenciesKey) ? Set<String>.from(pubspecYaml[devDependenciesKey].keys) : <String>{};
  logger.fine('dev_dependencies:\n'
      '${bulletItems(devDeps)}\n');

  final publicDirs = ['bin/', 'lib/'];
  final publicDartFiles = [
    for (final dir in publicDirs) ...listDartFilesIn(dir, excludes),
  ];
  final publicScssFiles = [
    for (final dir in publicDirs) ...listScssFilesIn(dir, excludes),
  ];
  final publicLessFiles = [
    for (final dir in publicDirs) ...listLessFilesIn(dir, excludes),
  ];

  logger
    ..fine('public facing dart files:\n'
        '${bulletItems(publicDartFiles.map((f) => f.path))}\n')
    ..fine('public facing scss files:\n'
        '${bulletItems(publicScssFiles.map((f) => f.path))}\n')
    ..fine('public facing less files:\n'
        '${bulletItems(publicLessFiles.map((f) => f.path))}\n');

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
  for (final file in publicLessFiles) {
    final matches = importLessPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedInPublicFiles.add(match.group(1));
    }
  }
  logger.fine('packages used in public facing files:\n'
      '${bulletItems(packagesUsedInPublicFiles)}\n');

  final publicDirGlobs = [for (final dir in publicDirs) Glob('$dir**')];

  final nonPublicDartFiles = listDartFilesIn('./', [...excludes, ...publicDirGlobs]);
  final nonPublicScssFiles = listScssFilesIn('./', [...excludes, ...publicDirGlobs]);
  final nonPublicLessFiles = listLessFilesIn('./', [...excludes, ...publicDirGlobs]);

  logger
    ..fine('non-public dart files:\n'
        '${bulletItems(nonPublicDartFiles.map((f) => f.path))}\n')
    ..fine('non-public scss files:\n'
        '${bulletItems(nonPublicScssFiles.map((f) => f.path))}\n')
    ..fine('non-public less files:\n'
        '${bulletItems(nonPublicLessFiles.map((f) => f.path))}\n');

  // Read each file outside lib/ and parse the package names from every
  // import and export directive.
  final packagesUsedOutsidePublicDirs = <String>{
    // For more info on analysis options:
    // https://dart.dev/guides/language/analysis-options#the-analysis-options-file
    if (optionsIncludePackage != null)
      optionsIncludePackage,
  };
  for (final file in nonPublicDartFiles) {
    final matches = importExportDartPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedOutsidePublicDirs.add(match.group(2));
    }
  }
  for (final file in nonPublicScssFiles) {
    final matches = importScssPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedOutsidePublicDirs.add(match.group(1));
    }
  }
  for (final file in nonPublicLessFiles) {
    final matches = importLessPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedOutsidePublicDirs.add(match.group(1));
    }
  }

  logger.fine('packages used outside public dirs:\n'
      '${bulletItems(packagesUsedOutsidePublicDirs)}\n');

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
    log(
      Level.WARNING,
      'These packages are used in lib/ but are not dependencies:',
      missingDependencies,
    );
    exitCode = 1;
  }

  // Packages that are used outside lib/ but are not dev_dependencies.
  final missingDevDependencies =
      // Start with packages _only_ used outside lib/
      packagesUsedOutsidePublicDirs
          .difference(packagesUsedInPublicFiles)
          // Remove all explicitly declared dependencies
          .difference(devDeps)
          .difference(deps)
            // Ignore self-imports - packages have implicit access to themselves.
            ..remove(packageName)
            // Ignore known missing packages.
            ..removeAll(ignoredPackages);

  if (missingDevDependencies.isNotEmpty) {
    log(
      Level.WARNING,
      'These packages are used outside lib/ but are not dev_dependencies:',
      missingDevDependencies,
    );
    exitCode = 1;
  }

  // Packages that are not used in lib/, but are used elsewhere, that are
  // dependencies when they should be dev_dependencies.
  final overPromotedDependencies =
      // Start with dependencies that are not used in lib/
      (deps
          .difference(packagesUsedInPublicFiles)
          // Intersect with deps that are used outside lib/ (excludes unused deps)
          .intersection(packagesUsedOutsidePublicDirs))
        // Ignore known over-promoted packages.
        ..removeAll(ignoredPackages);

  if (overPromotedDependencies.isNotEmpty) {
    log(
      Level.WARNING,
      'These packages are only used outside lib/ and should be downgraded to dev_dependencies:',
      overPromotedDependencies,
    );
    exitCode = 1;
  }

  // Packages that are used in lib/, but are dev_dependencies.
  final underPromotedDependencies =
      // Start with dev_dependencies that are used in lib/
      devDeps.intersection(packagesUsedInPublicFiles)
        // Ignore known under-promoted packages
        ..removeAll(ignoredPackages);

  if (underPromotedDependencies.isNotEmpty) {
    log(
      Level.WARNING,
      'These packages are used in lib/ and should be promoted to actual dependencies:',
      underPromotedDependencies,
    );
    exitCode = 1;
  }

  // Packages that are not used anywhere but are dependencies.
  var unusedDependencies =
      // Start with all explicitly declared dependencies
      deps
          .union(devDeps)
          // Remove all deps that were used in Dart code somewhere in this package
          .difference(packagesUsedInPublicFiles)
          .difference(packagesUsedOutsidePublicDirs)
            // Remove this package, since we know they're using our executable
            ..remove(dependencyValidatorPackageName);

  // Find unused packages that provide an executable. We assume those executables are used, but warn the user in case they are not.
  final consideredUsed = unusedDependencies.intersection(packagesWithExecutables);
  if (consideredUsed.isNotEmpty) {
    log(Level.INFO, 'the following packages contain executables, they are assumed to be used:', consideredUsed);
  }

  // Remove deps that provide an executable, assume that the executable is used
  unusedDependencies = unusedDependencies.difference(packagesWithExecutables);

  if (unusedDependencies.contains('analyzer')) {
    logger.warning(
      'You do not need to depend on `analyzer` to run the Dart analyzer.\n'
      'Instead, just run the `dartanalyzer` executable that is bundled with the Dart SDK.',
    );
  }

  // Ignore known unused packages
  unusedDependencies.removeAll(ignoredPackages);

  if (unusedDependencies.isNotEmpty) {
    log(
      Level.WARNING,
      'These packages may be unused, or you may be using assets from these packages:',
      unusedDependencies,
    );
    exitCode = 1;
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
    log(Level.WARNING, 'These packages are pinned in pubspec.yaml:', infractions);
    exitCode = 1;
  }
}
