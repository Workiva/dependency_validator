import 'dart:convert';
import 'dart:io';

import 'package:dependency_validator/src/dependency_validator.dart';
import 'package:dependency_validator/src/pubspec_config.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

export 'package:logging/logging.dart' show Level;

import 'pubspec_to_json.dart';

Future<ProcessResult> checkProject({
  DepValidatorConfig? config,
  Map<String, Dependency> dependencies = const {},
  Map<String, Dependency> devDependencies = const {},
  List<d.Descriptor> project = const [],
  List<String> args = const [],
  bool embedConfigInPubspec = false,
}) async {
  final pubspec = Pubspec(
    'project',
    environment: requireDart36,
    dependencies: dependencies,
    devDependencies: {
      ...devDependencies,
      'dependency_validator': PathDependency(Directory.current.absolute.path),
    },
  );
  final pubspecJson = pubspec.toJson();
  if (embedConfigInPubspec && config != null) {
    pubspecJson['dependency_validator'] = config.toJson();
  }
  final dir = d.dir('project', [
    ...project,
    d.file('pubspec.yaml', jsonEncode(pubspecJson)),
    if (config != null && !embedConfigInPubspec)
      d.file('dart_dependency_validator.yaml', jsonEncode(config.toJson())),
  ]);
  await dir.create();
  final path = '${d.sandbox}/project';
  final commandArgs = ['run', 'dependency_validator', '--verbose', ...args];
  return await Process.run('dart', commandArgs, workingDirectory: path);
}

Dependency hostedCompatibleWith(String version) => HostedDependency(
      version: VersionConstraint.compatibleWith(Version.parse(version)),
    );

Dependency hostedPinned(String version) =>
    HostedDependency(version: Version.parse(version));

final hostedAny = HostedDependency(version: VersionConstraint.any);

/// Removes indentation from `'''` string blocks.
String unindent(String multilineString) {
  var indent = RegExp(r'^( *)').firstMatch(multilineString)![1];
  assert(indent != null && indent.isNotEmpty);
  return multilineString.replaceAll('$indent', '');
}

void initLogs() =>
    Logger.root.onRecord.map((record) => record.message).listen(print);

final requireDart36 = {
  "sdk": VersionConstraint.compatibleWith(Version.parse('3.6.0')),
};

typedef WorkspaceSubpackage = ({
  String path,
  List<d.Descriptor> contents,
  Map<String, Dependency> deps,
  DepValidatorConfig? config,
});

/// Creates a workspace in the test sandbox and runs [checkPackage] on it.
///
/// By default the workspace has a single sub-package at `subpackage/`
/// described by [subpackage], [subpackageDeps], and [subpackageConfig]. Pass
/// [subpackages] instead to create several sub-packages at arbitrary paths;
/// the single-sub-package parameters must then be omitted.
///
/// [workspaceMembers] overrides the root pubspec's `workspace:` list (for
/// example to use glob patterns); it defaults to the sub-package paths.
///
/// Returns the log messages emitted at or above [logLevel] while validating.
Future<List<String>> checkWorkspace({
  required Map<String, Dependency> workspaceDeps,
  required List<d.Descriptor> workspace,
  Map<String, Dependency>? subpackageDeps,
  List<d.Descriptor>? subpackage,
  DepValidatorConfig? workspaceConfig,
  DepValidatorConfig? subpackageConfig,
  Level logLevel = Level.OFF,
  Matcher matcher = isTrue,
  List<String>? workspaceMembers,
  List<WorkspaceSubpackage>? subpackages,
}) async {
  if (subpackages != null) {
    expect(
      subpackage ?? subpackageDeps ?? subpackageConfig,
      isNull,
      reason: 'Pass either `subpackages` or the single-subpackage parameters '
          '(`subpackage`, `subpackageDeps`, `subpackageConfig`), not both.',
    );
  }
  final resolvedSubpackages = subpackages ??
      [
        (
          path: 'subpackage',
          contents: subpackage ?? const [],
          deps: subpackageDeps ?? const {},
          config: subpackageConfig,
        ),
      ];
  final workspacePubspec = Pubspec(
    'workspace',
    environment: requireDart36,
    dependencies: workspaceDeps,
    workspace:
        workspaceMembers ?? resolvedSubpackages.map((s) => s.path).toList(),
  );
  final dir = d.dir('workspace', [
    ...workspace,
    d.file('pubspec.yaml', jsonEncode(workspacePubspec.toJson())),
    if (workspaceConfig != null)
      d.file(
        'dart_dependency_validator.yaml',
        jsonEncode(workspaceConfig.toJson()),
      ),
    for (final subpackageSpec in resolvedSubpackages)
      d.dir(subpackageSpec.path, [
        ...subpackageSpec.contents,
        d.file(
          'pubspec.yaml',
          jsonEncode(
            Pubspec(
              p.basename(subpackageSpec.path),
              environment: requireDart36,
              dependencies: subpackageSpec.deps,
              resolution: 'workspace',
            ).toJson(),
          ),
        ),
        if (subpackageSpec.config != null)
          d.file(
            'dart_dependency_validator.yaml',
            jsonEncode(subpackageSpec.config!.toJson()),
          ),
      ]),
  ]);
  await dir.create();
  Logger.root.level = logLevel;
  final messages = <String>[];
  final subscription =
      Logger.root.onRecord.listen((record) => messages.add(record.message));
  try {
    final result = await checkPackage(root: '${d.sandbox}/workspace');
    expect(result, matcher);
  } finally {
    await subscription.cancel();
  }
  return messages;
}
