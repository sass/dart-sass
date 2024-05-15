// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import '../tool/grind/synchronize.dart' as synchronize;

/// Tests that double-check that everything in the repo looks sensible.
void main() {
  group("synchronized file is up-to-date:", () {
    synchronize.sources.forEach((sourcePath, targetPath) {
      test(targetPath, () {
        if (File(targetPath).readAsStringSync() !=
            synchronize.synchronizeFile(sourcePath)) {
          fail("$targetPath is out-of-date.\n"
              "Run `dart pub run grinder` to update it.");
        }
      });
    });
  },
      // Windows sees different bytes than other OSes, possibly because of
      // newline normalization issues.
      testOn: "!windows");

  for (var package in [
    ".",
    ...Directory("pkg").listSync().map((entry) => entry.path)
  ]) {
    group("in ${p.relative(package)}", () {
      test("pubspec version matches CHANGELOG version", () {
        var firstLine = const LineSplitter()
            .convert(File("$package/CHANGELOG.md").readAsStringSync())
            .first;
        expect(firstLine, startsWith("## "));
        var changelogVersion = Version.parse(firstLine.substring(3));

        var pubspec = Pubspec.parse(
            File("$package/pubspec.yaml").readAsStringSync(),
            sourceUrl: p.toUri("$package/pubspec.yaml"));
        expect(
            pubspec.version!.toString(),
            anyOf(
                equals(changelogVersion.toString()),
                changelogVersion.isPreRelease
                    ? equals("${changelogVersion.nextPatch}-dev")
                    : equals("$changelogVersion-dev")));
      });
    });
  }

  for (var package in Directory("pkg").listSync().map((entry) => entry.path)) {
    group("in pkg/${p.basename(package)}", () {
      late Pubspec sassPubspec;
      late Pubspec pkgPubspec;
      setUpAll(() {
        sassPubspec = Pubspec.parse(File("pubspec.yaml").readAsStringSync(),
            sourceUrl: Uri.parse("pubspec.yaml"));
        pkgPubspec = Pubspec.parse(
            File("$package/pubspec.yaml").readAsStringSync(),
            sourceUrl: p.toUri("$package/pubspec.yaml"));
      });

      test("depends on the current sass version", () {
        if (_isDevVersion(sassPubspec.version!)) return;

        expect(pkgPubspec.dependencies, contains("sass"));
        var dependency = pkgPubspec.dependencies["sass"]!;
        expect(dependency, isA<HostedDependency>());
        expect((dependency as HostedDependency).version,
            equals(sassPubspec.version));
      });

      test("increments along with the sass version", () {
        var sassVersion = sassPubspec.version!;
        if (_isDevVersion(sassVersion)) return;

        var pkgVersion = pkgPubspec.version!;
        expect(_isDevVersion(pkgVersion), isFalse,
            reason: "sass $sassVersion isn't a dev version but "
                "${pkgPubspec.name} $pkgVersion is");

        if (sassVersion.isPreRelease) {
          expect(pkgVersion.isPreRelease, isTrue,
              reason: "sass $sassVersion is a pre-release version but "
                  "${pkgPubspec.name} $pkgVersion isn't");
        }

        // If only sass's patch version was incremented, there's not a good way
        // to tell whether the sub-package's version was incremented as well
        // because we don't have access to the prior version.
        if (sassVersion.patch != 0) return;

        if (sassVersion.minor != 0) {
          expect(pkgVersion.patch, equals(0),
              reason: "sass minor version was incremented, ${pkgPubspec.name} "
                  "must increment at least its minor version");
        } else {
          expect(pkgVersion.minor, equals(0),
              reason: "sass major version was incremented, ${pkgPubspec.name} "
                  "must increment at its major version as well");
        }
      });

      test("matches SDK version", () {
        expect(pkgPubspec.environment!["sdk"],
            equals(sassPubspec.environment!["sdk"]));
      });

      test("matches dartdoc version", () {
        // TODO(nweiz): Just use equals() once dart-lang/pubspec_parse#127 lands
        // and is released.
        var sassDep = sassPubspec.devDependencies["dartdoc"];
        var pkgDep = pkgPubspec.devDependencies["dartdoc"];
        expect(pkgDep, isA<HostedDependency>());
        expect(sassDep, isA<HostedDependency>());
        expect((pkgDep as HostedDependency).version,
            equals((sassDep as HostedDependency).version));
      });
    });
  }
}

/// Returns whether [version] is a `-dev` version.
bool _isDevVersion(Version version) =>
    version.preRelease.length == 1 && version.preRelease.first == 'dev';
