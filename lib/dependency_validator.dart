import 'dart:io';

import 'package:yaml/yaml.dart';

import './src/utils.dart';

/// Check for missing, under-promoted, over-promoted, and unused dependencies.
void run({List<String> ignoredPackages = const []}) {
  // Read and parse the pubspec.yaml in the current working directory.
  final YamlMap pubspecYaml = loadYaml(new File('pubspec.yaml').readAsStringSync());

  // Extract the package name.
  final packageName = pubspecYaml[nameKey];

  logger.info('Validating dependencies for $packageName');

  // Extract the package names from the `dependencies` section.
  final deps = pubspecYaml.containsKey(dependenciesKey)
      ? new Set<String>.from(pubspecYaml[dependenciesKey].keys)
      : new Set<String>();
  logger.fine('dependencies:\n${bulletItems(deps)}\n');

  // Extract the package names from the `dev_dependencies` section.
  final devDeps = pubspecYaml.containsKey(devDependenciesKey)
      ? new Set<String>.from(pubspecYaml[devDependenciesKey].keys)
      : new Set<String>();
  logger.fine('dev_dependencies:\n'
      '${bulletItems(devDeps)}\n');

  // Extract the package names from the `transformers` section.
  final Iterable transformerEntries = pubspecYaml[transformersKey];
  final packagesUsedViaTransformers = pubspecYaml.containsKey(transformersKey)
      ? new Set<String>.from(transformerEntries.map<String>((value) {
          if (value is YamlMap) return value.keys.first;
          return value;
        }).map((value) => value.replaceFirst(new RegExp(r'\/.*'), '')))
      : new Set<String>();
  logger.fine('transformers:\n'
      '${bulletItems(packagesUsedViaTransformers)}\n');

  // Recursively list all Dart files in lib/
  final publicDartFiles = <File>[]..addAll(listDartFilesIn('lib/'))..addAll(listDartFilesIn('bin/'));
  logger.fine('public facing dart files:\n'
      '${bulletItems(publicDartFiles.map((f) => f.path))}\n');

  // Read each file in lib/ and parse the package names from every import and
  // export directive.
  final packagesUsedInPublicFiles = new Set<String>();
  for (final file in publicDartFiles) {
    final matches = importExportPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedInPublicFiles.add(match.group(2));
    }
  }
  logger.fine('packages used in public facing files:\n'
      '${bulletItems(packagesUsedInPublicFiles)}\n');

  // Recursively list all Dart files in known directories other than lib/
  final nonLibDartFiles = <File>[]
    ..addAll(listDartFilesIn('example/'))
    ..addAll(listDartFilesIn('test/'))
    ..addAll(listDartFilesIn('tool/'))
    ..addAll(listDartFilesIn('web/'));
  logger.fine('non-lib dart files:\n'
      '${bulletItems(nonLibDartFiles.map((f) => f.path))}\n');

  // Read each file outside lib/ and parse the package names from every
  // import and export directive.
  final packagesUsedOutsideLib = new Set<String>();
  for (final file in nonLibDartFiles) {
    final matches = importExportPackageRegex.allMatches(file.readAsStringSync());
    for (final match in matches) {
      packagesUsedOutsideLib.add(match.group(2));
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
            ..remove(packageName);

  if (missingDependencies.isNotEmpty) {
    logDependencyInfractions(
      'These packages are used in lib/ but are not dependencies:',
      missingDependencies,
    );
    exitCode = 1;
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
            ..remove(packageName);

  if (missingDevDependencies.isNotEmpty) {
    logDependencyInfractions(
      'These packages are used outside lib/ but are not dev_dependencies:',
      missingDevDependencies,
    );
    exitCode = 1;
  }

  // Packages that are not used in lib/, but are used elsewhere, that are
  // dependencies when they should be dev_dependencies.
  final overPromotedDependencies =
      // Start with dependencies that are not used in lib/
      deps
          .difference(packagesUsedInPublicFiles)
          // Intersect with deps that are used outside lib/ (excludes unused deps)
          .intersection(packagesUsedOutsideLib);

  if (overPromotedDependencies.isNotEmpty) {
    logDependencyInfractions(
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
    logDependencyInfractions(
      'These packages are used in lib/ and should be promoted to actual dependencies:',
      underPromotedDependencies,
    );
    exitCode = 1;
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
            ..remove(dependencyValidatorPackageName)
            // Ignore known unused packages
            ..removeAll(ignoredPackages);

  if (unusedDependencies.isNotEmpty) {
    logDependencyInfractions(
      'These packages may be unused, or you may be using executables or assets from these packages:',
      unusedDependencies,
    );

    exitCode = 1;
  }

  if (exitCode == 0) {
    logger.info('No infractions found, $packageName is good to go!');
  }
}
