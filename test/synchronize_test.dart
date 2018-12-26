// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../tool/grind/synchronize.dart' as synchronize;

void main() {
  test("synchronized files are up-to-date", () {
    synchronize.sources.forEach((sourcePath, targetPath) {
      var source = File(sourcePath).readAsStringSync();
      var target = File(targetPath).readAsStringSync();

      var hash = sha1.convert(utf8.encode(source));
      if (!target.contains("Checksum: $hash")) {
        fail("$targetPath is out-of-date.\n"
            "Run pub run grinder to update it.");
      }
    });
  });
}
