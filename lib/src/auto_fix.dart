import 'package:dependency_validator/src/utils.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

class AutoFix {
  final Pubspec pubspec;

  final _pubRemoveNames = <String>[];
  final _pubAdds = <PubAddCommand>[];

  AutoFix(this.pubspec);

  void handleMissingDependencies(Set<String> deps) {
    _pubAdds.addAll(deps.map((dep) => PubAddCommand(packageAndConstraints: [dep], dev: false)));
  }

  void handleMissingDevDependencies(Set<String> deps) {
    _pubAdds.addAll(deps.map((dep) => PubAddCommand(packageAndConstraints: [dep], dev: true)));
  }

  void handleOverPromotedDependencies(Set<String> deps) {
    _pubRemoveNames.addAll(deps);
    _pubAdds.addAll(_parsePubAddListByPubspec(deps, dev: true));
  }

  void handleUnderPromotedDependencies(Set<String> deps) {
    _pubRemoveNames.addAll(deps);
    _pubAdds.addAll(_parsePubAddListByPubspec(deps, dev: false));
  }

  void handleUnusedDependencies(Set<String> deps) {
    _pubRemoveNames.addAll(deps);
  }

  List<PubAddCommand> _parsePubAddListByPubspec(Set<String> deps, {required bool dev}) {
    return deps.map((dep) => _parsePubAddByPubspec(dep, dev: dev)).where((e) => e != null).map((e) => e!).toList();
  }

  PubAddCommand? _parsePubAddByPubspec(String name, {required bool dev}) {
    final dependency = pubspec.dependencies[name] ?? pubspec.devDependencies[name];
    if (dependency == null) {
      logger.warning('WARN: cannot find dependency name=$name');
      return null;
    }

    if (dependency is HostedDependency) {
      final constraint = dependency.version.toString();
      return PubAddCommand(packageAndConstraints: ['$name:$constraint'], dev: dev);
    }

    if (dependency is PathDependency) {
      return PubAddCommand(
        packageAndConstraints: [name],
        dev: dev,
        extraArgs: '--path ${dependency.path}',
      );
    }

    if (dependency is GitDependency) {
      var extraArgs = '--git-url ${dependency.url} ';
      if (dependency.ref != null) extraArgs += '--git-ref ${dependency.ref} ';
      if (dependency.path != null) extraArgs += '--git-path ${dependency.path} ';

      return PubAddCommand(
        packageAndConstraints: [name],
        dev: dev,
        extraArgs: extraArgs,
      );
    }

    logger.warning('WARN: do not know type of dependency '
        'name=$name dependency=$dependency type=${dependency.runtimeType}');
    return null;
  }

  String compile() {
    final mergedPubAdds = PubAddCommand.merge(_pubAdds);
    return [
      if (_pubRemoveNames.isNotEmpty) 'dart pub remove ' + _pubRemoveNames.join(' '),
      ...mergedPubAdds.map((e) => e.compile()),
    ].join(' && ');
  }
}

class PubAddCommand {
  final bool dev;
  final List<String> packageAndConstraints;
  final String? extraArgs;

  PubAddCommand({
    required this.packageAndConstraints,
    required this.dev,
    this.extraArgs,
  });

  String compile() {
    var ans = 'dart pub add ';
    if (dev) ans += '--dev ';
    ans += packageAndConstraints.join(' ') + ' ';
    ans += extraArgs ?? '';
    return ans;
  }

  static List<PubAddCommand> merge(List<PubAddCommand> commands) {
    final simpleAdd = <PubAddCommand>[];
    final simpleAddDev = <PubAddCommand>[];
    final others = <PubAddCommand>[];

    for (final command in commands) {
      if (command.extraArgs == null) {
        (command.dev ? simpleAddDev : simpleAdd).add(command);
      } else {
        others.add(command);
      }
    }

    return [
      if (simpleAdd.isNotEmpty)
        PubAddCommand(
          packageAndConstraints: simpleAdd.expand((c) => c.packageAndConstraints).toList(),
          dev: false,
        ),
      if (simpleAddDev.isNotEmpty)
        PubAddCommand(
          packageAndConstraints: simpleAddDev.expand((c) => c.packageAndConstraints).toList(),
          dev: true,
        ),
      ...others,
    ];
  }
}
