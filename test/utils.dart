import 'dart:convert';
import 'dart:io';

import 'package:dependency_validator/src/dependency_validator.dart';
import 'package:dependency_validator/src/pubspec_config.dart';
import 'package:logging/logging.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

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

Future<bool> checkWorkspace({
  required Pubspec workspacePubspec,
  required List<d.Descriptor> workspace,
  required Pubspec subpackagePubspec,
  required List<d.Descriptor> subpackage,
  DepValidatorConfig? workspaceConfig,
  DepValidatorConfig? subpackageConfig,
  bool checkSubpackage = false,
  bool verbose = false,
}) async {
  final dir = d.dir('workspace', [
    ...workspace,
    d.file('pubspec.yaml', jsonEncode(workspacePubspec.toJson())),
    if (workspaceConfig != null)
      d.file('dart_dependency_validator.yaml', jsonEncode(workspaceConfig.toJson())),
    d.dir('subpackage', [
      ...subpackage,
      d.file('pubspec.yaml', jsonEncode(subpackagePubspec.toJson())),
      if (subpackageConfig != null)
        d.file('dart_dependency_validator.yaml', jsonEncode(subpackageConfig.toJson())),
    ]),
  ],);
  await dir.create();
  final root = checkSubpackage ? "subpackage" : "workspace";
  Logger.root.level = verbose ? Level.ALL : Level.OFF;
  return await checkPackage(root: "${d.sandbox}/$root");
}
