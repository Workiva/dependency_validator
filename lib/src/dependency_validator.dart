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

import 'package:build_config/build_config.dart';
import 'package:dependency_validator/src/import_export_ast_visitor.dart';
import 'package:io/ansi.dart';
import 'package:logging/logging.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';

import 'constants.dart';
import 'pubspec_config.dart';
import 'utils.dart';

/// Check for missing, under-promoted, over-promoted, and unused dependencies.
Future<bool> checkPackage({required String root}) async {
  var result = true;
  if (!File('$root/pubspec.yaml').existsSync()) {
    logger.shout(red.wrap('pubspec.yaml not found'));
    logger.fine('Path: $root/pubspec.yaml');
    return false;
  }

  DepValidatorConfig config;
  final configFile = File('$root/dart_dependency_validator.yaml');
  if (configFile.existsSync()) {
    config = DepValidatorConfig.fromYaml(configFile.readAsStringSync());
  } else {
    final pubspecConfig = PubspecDepValidatorConfig.fromYaml(
      File('$root/pubspec.yaml').readAsStringSync(),
    );
    if (pubspecConfig.isNotEmpty) {
      logger.warning(
        yellow.wrap(
          'Configuring dependency_validator in pubspec.yaml is deprecated.\n'
          'Use dart_dependency_validator.yaml instead.',
        ),
      );
    }
    config = pubspecConfig.dependencyValidator;
  }

  final excludes =
      config.exclude
          .map((s) {
            try {
              return makeGlob("$root/$s");
            } catch (_, __) {
              logger.shout(yellow.wrap('invalid glob syntax: "$s"'));
              return null;
            }
          })
          .nonNulls
          .toList();
  logger.fine('excludes:\n${bulletItems(excludes.map((g) => g.pattern))}\n');
  final ignoredPackages = config.ignore;
  logger.fine('ignored packages:\n${bulletItems(ignoredPackages)}\n');

  // Read and parse the analysis_options.yaml in the current working directory.
  final optionsIncludePackage = getAnalysisOptionsIncludePackage(path: root);

  // Read and parse the pubspec.yaml in the current working directory.
  final pubspecFile = File('$root/pubspec.yaml');
  final pubspec = Pubspec.parse(
    pubspecFile.readAsStringSync(),
    sourceUrl: pubspecFile.uri,
  );

  var subResult = true;
  if (pubspec.isWorkspaceRoot) {
    logger.fine('In a workspace. Recursing through sub-packages...');
    for (final package in pubspec.workspace ?? []) {
      subResult &= await checkPackage(root: '$root/$package');
      logger.info('');
    }
  }

  logger.info('Validating dependencies for ${pubspec.name}...');

  if (!config.allowPins) {
    checkPubspecForPins(pubspec, ignoredPackages: ignoredPackages);
  }

  // Extract the package names from the `dependencies` section.
  final deps = Set<String>.from(pubspec.dependencies.keys);
  logger.fine('dependencies:\n${bulletItems(deps)}\n');

  // Extract the package names from the `dev_dependencies` section.
  final devDeps = Set<String>.from(pubspec.devDependencies.keys);
  logger.fine(
    'dev_dependencies:\n'
    '${bulletItems(devDeps)}\n',
  );

  final publicDirs = ['$root/bin/', '$root/lib/'];
  logger.fine("Excluding: $excludes");
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
    ..fine(
      'public facing dart files:\n'
      '${bulletItems(publicDartFiles.map((f) => f.path))}\n',
    )
    ..fine(
      'public facing scss files:\n'
      '${bulletItems(publicScssFiles.map((f) => f.path))}\n',
    )
    ..fine(
      'public facing less files:\n'
      '${bulletItems(publicLessFiles.map((f) => f.path))}\n',
    );

  // Read each file in lib/ and parse the package names from every import and
  // export directive.
  final packagesUsedInPublicFiles = <String>{};
  for (final file in publicDartFiles) {
    packagesUsedInPublicFiles.addAll(getDartDirectivePackageNames(file));
  }
  for (final file in publicScssFiles) {
    final matches = importScssPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedInPublicFiles.add(match.group(1)!);
    }
  }
  for (final file in publicLessFiles) {
    final matches = importLessPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedInPublicFiles.add(match.group(1)!);
    }
  }
  logger.fine(
    'packages used in public facing files:\n'
    '${bulletItems(packagesUsedInPublicFiles)}\n',
  );

  final publicDirGlobs = [for (final dir in publicDirs) makeGlob('$dir**')];

  final subpackageGlobs = [
    for (final subpackage in pubspec.workspace ?? [])
      makeGlob('$root/$subpackage**'),
  ];

  logger.fine('subpackage globs: $subpackageGlobs');

  final nonPublicDartFiles = listDartFilesIn('$root/', [
    ...excludes,
    ...publicDirGlobs,
    ...subpackageGlobs,
  ]);
  final nonPublicScssFiles = listScssFilesIn('$root/', [
    ...excludes,
    ...publicDirGlobs,
    ...subpackageGlobs,
  ]);
  final nonPublicLessFiles = listLessFilesIn('$root/', [
    ...excludes,
    ...publicDirGlobs,
    ...subpackageGlobs,
  ]);

  logger
    ..fine(
      'non-public dart files:\n'
      '${bulletItems(nonPublicDartFiles.map((f) => f.path))}\n',
    )
    ..fine(
      'non-public scss files:\n'
      '${bulletItems(nonPublicScssFiles.map((f) => f.path))}\n',
    )
    ..fine(
      'non-public less files:\n'
      '${bulletItems(nonPublicLessFiles.map((f) => f.path))}\n',
    );

  // Read each file outside lib/ and parse the package names from every
  // import and export directive.
  final packagesUsedOutsidePublicDirs = <String>{
    // For more info on analysis options:
    // https://dart.dev/guides/language/analysis-options#the-analysis-options-file
    if (optionsIncludePackage != null && optionsIncludePackage.isNotEmpty)
      ...optionsIncludePackage,
  };
  for (final file in nonPublicDartFiles) {
    packagesUsedOutsidePublicDirs.addAll(getDartDirectivePackageNames(file));
  }
  for (final file in nonPublicScssFiles) {
    final matches = importScssPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedOutsidePublicDirs.add(match.group(1)!);
    }
  }
  for (final file in nonPublicLessFiles) {
    final matches = importLessPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedOutsidePublicDirs.add(match.group(1)!);
    }
  }

  logger.fine(
    'packages used outside public dirs:\n'
    '${bulletItems(packagesUsedOutsidePublicDirs)}\n',
  );

  // Packages that are used in lib/ but are not dependencies.
  final missingDependencies =
      // Start with packages used in lib/
      packagesUsedInPublicFiles
          // Remove all explicitly declared dependencies
          .difference(deps)
          .difference(devDeps)
        // Ignore self-imports - packages have implicit access to themselves.
        ..remove(pubspec.name)
        // Ignore known missing packages.
        ..removeAll(ignoredPackages);

  if (missingDependencies.isNotEmpty) {
    log(
      Level.WARNING,
      'These packages are used in lib/ but are not dependencies:',
      missingDependencies,
    );
    result = false;
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
        ..remove(pubspec.name)
        // Ignore known missing packages.
        ..removeAll(ignoredPackages);

  if (missingDevDependencies.isNotEmpty) {
    log(
      Level.WARNING,
      'These packages are used outside lib/ but are not dev_dependencies:',
      missingDevDependencies,
    );
    result = false;
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
    result = false;
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
    result = false;
  }

  // Packages that are not used anywhere but are dependencies.
  final unusedDependencies =
      // Start with all explicitly declared dependencies
      deps
          .union(devDeps)
          // Remove all deps that were used in Dart code somewhere in this package
          .difference(packagesUsedInPublicFiles)
          .difference(packagesUsedOutsidePublicDirs)
        // Remove this package, since we know they're using our executable
        ..remove(dependencyValidatorPackageName)
        ..removeAll(ignoredPackages);

  final packageConfig = await findPackageConfig(Directory.current);
  if (packageConfig == null) {
    logger.severe(
      red.wrap(
        'Could not find package config. Make sure you run `dart pub get` first.',
      ),
    );
    return false;
  }

  // Remove deps that provide builders that will be applied
  final rootBuildConfig = await BuildConfig.fromBuildConfigDir(
    pubspec.name,
    pubspec.dependencies.keys,
    '.',
  );
  bool rootPackageReferencesDependencyInBuildYaml(String dependencyName) => [
        ...rootBuildConfig.globalOptions.keys,
        for (final target in rootBuildConfig.buildTargets.values)
          ...target.builders.keys,
      ]
      .map((key) => normalizeBuilderKeyUsage(key, pubspec.name))
      .any((key) => key.startsWith('$dependencyName:'));

  final packagesWithConsumedBuilders = Set<String>();
  for (final name in unusedDependencies) {
    final package = packageConfig[name];
    if (package == null) continue;
    // Check if a builder is used from this package
    if (rootPackageReferencesDependencyInBuildYaml(package.name) ||
        await dependencyDefinesAutoAppliedBuilder(p.fromUri(package.root))) {
      packagesWithConsumedBuilders.add(package.name);
    }
  }

  logIntersection(
    Level.FINE,
    'The following packages contain builders that are auto-applied or referenced in "build.yaml"',
    unusedDependencies,
    packagesWithConsumedBuilders,
  );
  unusedDependencies.removeAll(packagesWithConsumedBuilders);

  // Remove deps that provide executables, those are assumed to be used
  bool providesExecutable(String name) {
    final package = packageConfig[name];
    if (package == null) return false;
    final binDir = Directory(p.join(p.fromUri(package.root), 'bin'));
    if (!binDir.existsSync()) return false;

    // Search for executables, if found we assume they are used
    return binDir.listSync().any((entity) => entity.path.endsWith('.dart'));
  }

  final packagesWithExecutables = {
    for (final package in unusedDependencies)
      if (providesExecutable(package)) package,
  };

  final nonDevPackagesWithExecutables =
      packagesWithExecutables.where(pubspec.dependencies.containsKey).toSet();
  if (nonDevPackagesWithExecutables.isNotEmpty) {
    logIntersection(
      Level.WARNING,
      'The following packages contain executables, and are only used outside of lib/. These should be downgraded to dev_dependencies:',
      unusedDependencies,
      nonDevPackagesWithExecutables,
    );
    result = false;
  }

  logIntersection(
    Level.INFO,
    'The following packages contain executables, they are assumed to be used:',
    unusedDependencies,
    packagesWithExecutables,
  );
  unusedDependencies.removeAll(packagesWithExecutables);

  if (unusedDependencies.contains('analyzer')) {
    logger.warning(
      yellow.wrap(
        'You do not need to depend on `analyzer` to run the Dart analyzer.\n'
        'Instead, just run the `dartanalyzer` executable that is bundled with the Dart SDK.',
      ),
    );
  }

  if (unusedDependencies.isNotEmpty) {
    log(
      Level.WARNING,
      'These packages may be unused, or you may be using assets from these packages:',
      unusedDependencies,
    );
    result = false;
  }

  if (result) {
    logger.info(green.wrap('✓ No dependency issues found!'));
  }
  return result && subResult;
}

/// Whether a dependency at [path] defines an auto applied builder.
Future<bool> dependencyDefinesAutoAppliedBuilder(String path) async =>
    (await BuildConfig.fromPackageDir(
      path,
    )).builderDefinitions.values.any((def) => def.autoApply != AutoApply.none);

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
void checkPubspecForPins(
  Pubspec pubspec, {
  List<String> ignoredPackages = const [],
}) {
  final List<String> infractions = [];
  infractions.addAll(
    getDependenciesWithPins(
      pubspec.dependencies,
      ignoredPackages: ignoredPackages,
    ),
  );

  infractions.addAll(
    getDependenciesWithPins(
      pubspec.devDependencies,
      ignoredPackages: ignoredPackages,
    ),
  );

  if (infractions.isNotEmpty) {
    log(
      Level.WARNING,
      'These packages are pinned in pubspec.yaml:',
      infractions,
    );
    exitCode = 1;
  }
}
