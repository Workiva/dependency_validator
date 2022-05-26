import 'package:pubspec_parse/pubspec_parse.dart';

class AutoFix {
  final _pubAdd = <String>[];
  final _pubAddDev = <String>[];
  final _pubRemove = <String>[];

  void handleMissingDependencies(Set<String> deps) {
    _pubAdd.addAll(deps);
  }

  void handleMissingDevDependencies(Set<String> deps) {
    _pubAddDev.addAll(deps);
  }

  void handleOverPromotedDependencies(Set<String> deps, Pubspec pubspec) {
    _pubRemove.addAll(deps);
    _pubAddDev.addAll(TODO);
  }

  void handleUnderPromotedDependencies(Set<String> deps, Pubspec pubspec) {
    _pubRemove.addAll(deps);
    _pubAdd.addAll(TODO);
  }

  void handleUnusedDependencies(Set<String> deps) {
    _pubRemove.addAll(deps);
  }

  List<String> compile() {
    return [
      'dart remove ' + _pubRemove.join(' '),
      'dart pub add ' + _pubAdd.join(' '),
      'dart pub add --dev ' + _pubAddDev.join(' '),
    ];
  }
}
