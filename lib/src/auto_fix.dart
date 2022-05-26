import 'package:pubspec_parse/pubspec_parse.dart';

class AutoFix {
  final Pubspec pubspec;

  final _pubAdd = <String>[];
  final _pubAddDev = <String>[];
  final _pubRemove = <String>[];

  AutoFix(this.pubspec);

  void handleMissingDependencies(Set<String> deps) {
    _pubAdd.addAll(deps);
  }

  void handleMissingDevDependencies(Set<String> deps) {
    _pubAddDev.addAll(deps);
  }

  void handleOverPromotedDependencies(Set<String> deps) {
    _pubRemove.addAll(deps);
    _pubAddDev.addAll(_parseDepsWithConstraints(deps));
  }

  void handleUnderPromotedDependencies(Set<String> deps) {
    _pubRemove.addAll(deps);
    _pubAdd.addAll(_parseDepsWithConstraints(deps));
  }

  void handleUnusedDependencies(Set<String> deps) {
    _pubRemove.addAll(deps);
  }

  List<String> _parseDepsWithConstraints(Set<String> deps) {
    return deps.map((dep) => _parseConstraint(dep)).where((e) => e != null).map((e) => e!).toList();
  }

  String? _parseConstraint(String name) {
    final dependency = pubspec.dependencies[name] ?? pubspec.devDependencies[name];
    if (dependency == null || dependency is! HostedDependency) return null;
    final constraint = dependency.version.toString();
    return name + ':' + constraint;
  }

  String compile() {
    return [
      'dart remove ' + _pubRemove.join(' '),
      'dart pub add ' + _pubAdd.join(' '),
      'dart pub add --dev ' + _pubAddDev.join(' '),
    ].join(' && ');
  }
}
