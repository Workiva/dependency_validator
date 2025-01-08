
import "package:pubspec_parse/pubspec_parse.dart";

extension <K, V> on Map<K, V> {
  Iterable<(K, V)> get records sync* {
    for (final entry in entries) {
      yield (entry.key, entry.value);
    }
  }
}

typedef Json = Map<String, dynamic>;

extension on Dependency {
  Json toJson() => switch (this) {
    SdkDependency(:final sdk, :final version) => {
      "sdk": sdk,
      "version": version.toString(),
    },
    HostedDependency(:final hosted, :final version) => {
      if (hosted != null) "hosted": hosted.url.toString(),
      "version": version.toString(),
    },
    GitDependency(:final url, :final ref, :final path) => {
      "git": {
        "url": url.toString(),
        if (path != null) "ref": ref,
        if (path != null) "path": path,
      },
    },
    PathDependency(:final path) => {
      "path": path.replaceAll(r'\', '/'),
    },
  };
}

/// An as-needed implementation of `Pubspec.toJson` for testing.
///
/// See: https://github.com/dart-lang/tools/issues/1801
extension PubspecToJson on Pubspec {
  Json toJson() => {
    "name": name,
    "environment": {
      for (final (sdk, version) in environment.records)
        sdk: version.toString(),
    },
    if (resolution != null) "resolution": resolution,
    if (workspace != null) "workspace": workspace,
    "dependencies": {
      for (final (name, dependency) in dependencies.records)
        name: dependency.toJson(),
    },
    // ...
  };
}
