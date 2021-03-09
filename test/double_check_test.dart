// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../tool/grind/synchronize.dart' as synchronize;

/// Tests that double-check that everything in the repo looks sensible.
void main() {
  group("synchronized file is up-to-date:", () {
    /// The pattern of a checksum in a generated file.
    var checksumPattern = RegExp(r"^// Checksum: (.*)$", multiLine: true);

    synchronize.sources.forEach((sourcePath, targetPath) {
      test(targetPath, () {
        var target = File(targetPath).readAsStringSync();
        var actualHash = checksumPattern.firstMatch(target)[1];

        var source = File(sourcePath).readAsBytesSync();
        var expectedHash = sha1.convert(source).toString();
        expect(actualHash, equals(expectedHash),
            reason: "$targetPath is out-of-date.\n"
                "Run pub run grinder to update it.");
      });
    });
  },
      // Windows sees different bytes than other OSes, possibly because of
      // newline normalization issues.
      testOn: "!windows");

  test("pubspec version matches CHANGELOG version", () {
    var firstLine = const LineSplitter()
        .convert(File("CHANGELOG.md").readAsStringSync())
        .first;
    expect(firstLine, startsWith("## "));
    var changelogVersion = firstLine.substring(3);

    var pubspec = loadYaml(File("pubspec.yaml").readAsStringSync(),
        sourceUrl: Uri(path: "pubspec.yaml")) as Map<dynamic, dynamic>;
    expect(pubspec, containsPair("version", isA<String>()));
    var pubspecVersion = pubspec["version"] as String;

    expect(pubspecVersion,
        anyOf(equals(changelogVersion), equals("$changelogVersion-dev")));
  });
}
