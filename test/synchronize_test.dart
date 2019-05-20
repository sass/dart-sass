// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// Windows sees different bytes than other OSes, possibly because of newline
// normalization issues.
@TestOn('vm && !windows')

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../tool/grind/synchronize.dart' as synchronize;

/// The pattern of a checksum in a generated file.
final _checksumPattern = RegExp(r"^// Checksum: (.*)$", multiLine: true);

void main() {
  synchronize.sources.forEach((sourcePath, targetPath) {
    test("synchronized file $targetPath is up-to-date", () {
      var target = File(targetPath).readAsStringSync();
      var actualHash = _checksumPattern.firstMatch(target)[1];

      var source = File(sourcePath).readAsBytesSync();
      var expectedHash = sha1.convert(source).toString();
      expect(actualHash, equals(expectedHash),
          reason: "$targetPath is out-of-date.\n"
              "Run pub run grinder to update it.");
    });
  });
}
