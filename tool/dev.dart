import 'package:dart_dev/dart_dev.dart' show dev, config;

main(List<String> args) async {
  config.format
    ..lineLength = 120
    ..paths = const ['bin/', 'lib/', 'test/', 'tool/'];

  config.analyze.entryPoints = const ['bin/', 'lib/', 'test/', 'tool/'];

  // config.copyLicense.directories = const ['bin/', 'lib/', 'test/', 'tool/'];

  config.test.unitTests = const ['test/'];

  await dev(args);
}
