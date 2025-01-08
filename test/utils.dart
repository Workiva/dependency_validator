import 'dart:convert';
import 'dart:io';

import 'package:dependency_validator/src/dependency_validator.dart';
import 'package:dependency_validator/src/pubspec_config.dart';
import 'package:logging/logging.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

export 'package:logging/logging.dart' show Level;

import 'pubspec_to_json.dart';

ProcessResult checkProject(
  String projectPath, {
  List<String> optionalArgs = const [],
}) {
  final pubGetResult = Process.runSync(
    'dart',
    ['pub', 'get'],
    workingDirectory: projectPath,
  );
  if (pubGetResult.exitCode != 0) {
    return pubGetResult;
  }

  final args = [
    'run',
    'dependency_validator',
    // This makes it easier to print(result.stdout) for debugging tests
    '--verbose',
    ...optionalArgs,
  ];

  return Process.runSync('dart', args, workingDirectory: projectPath);
}

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

Future<void> checkWorkspace({
  required Map<String, Dependency> workspaceDeps,
  required Map<String, Dependency> subpackageDeps,
  required List<d.Descriptor> workspace,
  required List<d.Descriptor> subpackage,
  DepValidatorConfig? workspaceConfig,
  DepValidatorConfig? subpackageConfig,
  Level logLevel = Level.OFF,
  Matcher matcher = isTrue,
}) async {
  final workspacePubspec = Pubspec(
    'workspace',
    environment: requireDart36,
    dependencies: workspaceDeps,
    workspace: ['subpackage'],
  );
  final subpackagePubspec = Pubspec(
    'subpackage',
    environment: requireDart36,
    dependencies: subpackageDeps,
    resolution: 'workspace',
  );
  final dir = d.dir(
    'workspace',
    [
      ...workspace,
      d.file('pubspec.yaml', jsonEncode(workspacePubspec.toJson())),
      if (workspaceConfig != null)
        d.file('dart_dependency_validator.yaml',
            jsonEncode(workspaceConfig.toJson())),
      d.dir('subpackage', [
        ...subpackage,
        d.file('pubspec.yaml', jsonEncode(subpackagePubspec.toJson())),
        if (subpackageConfig != null)
          d.file('dart_dependency_validator.yaml',
              jsonEncode(subpackageConfig.toJson())),
      ]),
    ],
  );
  await dir.create();
  Logger.root.level = logLevel;
  final result = await checkPackage(root: '${d.sandbox}/workspace');
  expect(result, matcher);
}
