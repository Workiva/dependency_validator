import 'package:pubspec_parse/pubspec_parse.dart';

class AutoFix {
  final commands = <String>[];

  void handleMissingDependencies(Set<String> deps) {
    commands.add('dart pub add ' + deps.join(' '));
  }

  void handleMissingDevDependencies(Set<String> deps) {
    commands.add('dart pub add --dev ' + deps.join(' '));
  }

  void handleOverPromotedDependencies(Set<String> deps, Pubspec pubspec) {
    TODO;
  }

  void handleUnderPromotedDependencies(Set<String> deps, Pubspec pubspec) {
    TODO;
  }

  void handleUnusedDependencies(Set<String> deps) {
    commands.add('dart remove ' + deps.join(' '));
  }
}
