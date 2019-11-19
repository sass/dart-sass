// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group("YAML files are valid:", () {
    for (var entry in Directory.current.listSync()) {
      if (entry is File &&
          (entry.path.endsWith(".yaml") || entry.path.endsWith(".yml"))) {
        test(p.basename(entry.path), () {
          // Shouldn't throw an error.
          loadYaml(entry.readAsStringSync());
        });
      }
    }
  });
}
