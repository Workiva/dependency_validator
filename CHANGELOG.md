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
