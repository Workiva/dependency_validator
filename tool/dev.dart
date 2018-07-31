// Copyright 2017 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:dart_dev/dart_dev.dart';

Future<Null> main(List<String> args) async {
  config.format
    ..lineLength = 120
    ..paths = const ['bin/', 'lib/', 'test/', 'tool/'];

  config.analyze.entryPoints = const ['bin/', 'lib/', 'test/', 'tool/'];

  config.copyLicense.directories = const ['bin/', 'lib/', 'test/', 'test_fixtures/', 'tool/'];

  await dev(args);
}
