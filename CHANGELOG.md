# 3.0.0

- **Breaking:** removed the public `package:dependency_validator/dependency_validator.dart`
entrypoint. It was only intended for this package to provide an executable and
the Dart APIs don't need to be public.
- Null safety.

# 2.0.1

- Fix a path issue on Windows.

# 2.0.0

- **Breaking Change:** Excluded paths and ignored packages must now be
configured statically in your project's `pubspec.yaml` instead of via
command-line arguments. See the README for more information.

- Detect packages with one or more executables and consider them to be used.
In other words, you no longer need to ignore packages that are only used for
their executable(s).

- Detect packages that provide one or more builders that are configured to be
auto-applied by the [dart build system][dart-build] and consider them to be
used. In other words, you no longer need to ignore packages that are only used
for their builder(s).

[dart-build]: https://github.com/dart-lang/build

# 1.5.0

- Scan `.less` files for Dart package imports.

# 1.4.2

- Detect package usage in `analysis_options.yaml` files.

# 1.4.1

- Add `dart_dev` to common binaries list so that it is automatically ignored.

# 1.4.0

- **Improvement:** Add `coverage` and `build_vm_compilers` to the list of
  commonly used binary packages that are ignored by default. [#50][#50]

- Raised minimum Dart SDK version to 2.2.0 (no longer supports Dart 1). [#50][#50]

[#50]: https://github.com/Workiva/dependency_validator/pull/50

# 1.3.0

- **Improvement:** Ignore commonly used binary packages by default. This can be
  disabled via `--no-ignore-common-binaries`.
  Run `pub run dependency_validator -h` to see which packages will be ignored by
  this flag. [#47][#47]

[#47]: https://github.com/Workiva/dependency_validator/pull/47

# 1.2.4

- **Bug Fix:** Ignoring a package via `--ignore` or `-i` will now also work as
  expected for the "over-promoted" failure. [#44][#44]

[#44]: https://github.com/Workiva/dependency_validator/pull/44

# 1.2.2

- **Bug Fix:** Ignoring a package via `--ignore` or `-i` will now also
  work as expected for the "pinned dependency" failure. [#39][#39]

[#39]: https://github.com/Workiva/dependency_validator/pull/39

# 1.2.1

- Dart 2 compatible. [#35][#35]

[#35]: https://github.com/Workiva/dependency_validator/pull/35

# 1.2.0

- **Feature:** Pinning a dependency (i.e. preventing patch or minor versions
  from being consumed) now causes validator to fail. You can opt-out of this
  feature with `--no-fatal-pins`. [#27][#27]

- **Feature:** Added a `--help` flag that outputs usage information. [#28][#28]

- **Improvement:** Package imports in `.scss` files are now detected.
  [#26][#26]

[#28]: https://github.com/Workiva/dependency_validator/pull/28
[#27]: https://github.com/Workiva/dependency_validator/pull/27
[#26]: https://github.com/Workiva/dependency_validator/pull/26

# 1.1.2

- Initial Dart 2/DDC compatibility changes. [#23][#23]

[#23]: https://github.com/Workiva/dependency_validator/pull/23

# 1.1.1

- **Bug Fix:** Fix detection of packages whose names contain numbers. [#17][#17]

[#17]: https://github.com/Workiva/dependency_validator/pull/17

# 1.1.0

- **Feature:** Added flags to control the types of validations that this tool
  enforces. They all default to true, but can be opted out of like so:

  - `--no-fatal-missing`
  - `--no-fatal-under-promoted`
  - `--no-fatal-over-promoted`
  - `--no-fatal-unused`

    [#14][#14]

- **Feature:** Added `--exclude-dir` to allow excluding an entire directory from
  the dependency validator checks. [#15][#15]

[#15]: https://github.com/Workiva/dependency_validator/pull/15
[#14]: https://github.com/Workiva/dependency_validator/pull/14

# 1.0.1

- **Bug Fix:** Packages ignored via the `--ignore` option will no longer be
  reported at all (previously they were only being ignored in the "unused"
  list). [#10][#10] [#12][#12]

[#12]: https://github.com/Workiva/dependency_validator/pull/12
[#10]: https://github.com/Workiva/dependency_validator/pull/10

# 1.0.0

- Initial version!
