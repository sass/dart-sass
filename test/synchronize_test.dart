// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  test("synchronized files are up-to-date", () {
    ({
      'lib/src/visitor/async_evaluate.dart': 'lib/src/visitor/evaluate.dart',
      'lib/src/async_environment.dart': 'lib/src/environment.dart'
    })
        .forEach((sourcePath, targetPath) {
      var source = new File(sourcePath).readAsStringSync();
      var target = new File(targetPath).readAsStringSync();

      var hash = sha1.convert(utf8.encode(source));
      if (!target.contains("Checksum: $hash")) {
        fail("$targetPath is out-of-date.\n"
            "Run pub run grinder to update it.");
      }
    });
  });
}
