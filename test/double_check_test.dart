// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import '../tool/grind/generate_deprecations.dart' as deprecations;
import '../tool/grind/synchronize.dart' as synchronize;

/// Tests that double-check that everything in the repo looks sensible.
void main() {
  group("up-to-date generated", () {
    group("synchronized file:", () {
      synchronize.sources.forEach((sourcePath, targetPath) {
        test(targetPath, () {
          if (File(targetPath).readAsStringSync() !=
              synchronize.synchronizeFile(sourcePath)) {
            fail("$targetPath is out-of-date.\n"
                "Run `dart run grinder` to update it.");
          }
        });
      });
    });

    test("deprecations", () {
      var inputText = File(deprecations.yamlPath).readAsStringSync();
      var outputText = File(deprecations.dartPath).readAsStringSync();
      var checksum = sha1.convert(utf8.encode(inputText));
      if (!outputText.contains('// Checksum: $checksum')) {
        fail('${deprecations.dartPath} is out-of-date.\n'
            'Run `dart run grinder` to update it.');
      }
    });
  },
      // Windows sees different bytes than other OSes, possibly because of
      // newline normalization issues.
      testOn: "!windows");

  for (var package in [".", "pkg/sass_api"]) {
    group("in ${p.relative(package)}", () {
      test("pubspec version matches CHANGELOG version", () {
        var pubspec = Pubspec.parse(
            File("$package/pubspec.yaml").readAsStringSync(),
            sourceUrl: p.toUri("$package/pubspec.yaml"));
        expect(pubspec.version!.toString(),
            matchesChangelogVersion(_changelogVersion(package)));
      });
    });
  }

  group("in pkg/sass_api", () {
    late Pubspec sassPubspec;
    late Pubspec pkgPubspec;
    setUpAll(() {
      sassPubspec = Pubspec.parse(File("pubspec.yaml").readAsStringSync(),
          sourceUrl: Uri.parse("pubspec.yaml"));
      pkgPubspec = Pubspec.parse(
          File("pkg/sass_api/pubspec.yaml").readAsStringSync(),
          sourceUrl: p.toUri("pkg/sass_api/pubspec.yaml"));
    });

    test("depends on the current sass version", () {
      if (_isDevVersion(sassPubspec.version!)) return;

      expect(pkgPubspec.dependencies, contains("sass"));
      var dependency = pkgPubspec.dependencies["sass"]!;
      expect(dependency, isA<HostedDependency>());
      expect((dependency as HostedDependency).version,
          equals(sassPubspec.version));
    });

    test(
        "increments along with the sass version",
        () => _checkVersionIncrementsAlong(
            'sass_api', sassPubspec, pkgPubspec.version!));

    test("matches SDK version", () {
      expect(pkgPubspec.environment!["sdk"],
          equals(sassPubspec.environment!["sdk"]));
    });

    test("matches dartdoc version", () {
      expect(sassPubspec.devDependencies["dartdoc"],
          equals(pkgPubspec.devDependencies["dartdoc"]));
    });
  });

  group("in pkg/sass-parser", () {
    late Pubspec sassPubspec;
    late Map<String, Object?> packageJson;
    setUpAll(() {
      sassPubspec = Pubspec.parse(File("pubspec.yaml").readAsStringSync(),
          sourceUrl: Uri.parse("pubspec.yaml"));
      packageJson =
          json.decode(File("pkg/sass-parser/package.json").readAsStringSync());
    });

    test(
        "package.json version matches CHANGELOG version",
        () => expect(packageJson["version"].toString(),
            matchesChangelogVersion(_changelogVersion("pkg/sass-parser"))));

    test("depends on the current sass version", () {
      if (_isDevVersion(sassPubspec.version!)) return;

      var dependencies = packageJson["dependencies"] as Map<String, Object?>;
      expect(
          dependencies, containsPair("sass", sassPubspec.version.toString()));
    });

    test(
        "increments along with the sass version",
        () => _checkVersionIncrementsAlong('sass-parser', sassPubspec,
            Version.parse(packageJson["version"] as String)));
  });
}

/// Returns whether [version] is a `-dev` version.
bool _isDevVersion(Version version) =>
    version.preRelease.length == 1 && version.preRelease.first == 'dev';

/// Returns the most recent version in the CHANGELOG for [package].
Version _changelogVersion(String package) {
  var firstLine = const LineSplitter()
      .convert(File("$package/CHANGELOG.md").readAsStringSync())
      .first;
  expect(firstLine, startsWith("## "));
  return Version.parse(firstLine.substring(3));
}

/// Returns a [Matcher] that matches any valid variant of the CHANGELOG version
/// [version] that the package itself can have.
Matcher matchesChangelogVersion(Version version) => anyOf(
    equals(version.toString()),
    version.isPreRelease
        ? equals("${version.nextPatch}-dev")
        : equals("$version-dev"));

/// Verifies that [pkgVersion] loks like it was incremented when the version of
/// the main Sass version was as well.
void _checkVersionIncrementsAlong(
    String pkgName, Pubspec sassPubspec, Version pkgVersion) {
  var sassVersion = sassPubspec.version!;
  if (_isDevVersion(sassVersion)) return;

  expect(_isDevVersion(pkgVersion), isFalse,
      reason: "sass $sassVersion isn't a dev version but $pkgName $pkgVersion "
          "is");

  if (sassVersion.isPreRelease) {
    expect(pkgVersion.isPreRelease, isTrue,
        reason: "sass $sassVersion is a pre-release version but $pkgName "
            "$pkgVersion isn't");
  }

  // If only sass's patch version was incremented, there's not a good way
  // to tell whether the sub-package's version was incremented as well
  // because we don't have access to the prior version.
  if (sassVersion.patch != 0) return;

  if (sassVersion.minor != 0) {
    expect(pkgVersion.patch, equals(0),
        reason: "sass minor version was incremented, $pkgName must increment "
            "at least its minor version");
  } else {
    expect(pkgVersion.minor, equals(0),
        reason: "sass major version was incremented, $pkgName must increment "
            "at its major version as well");
  }
}
