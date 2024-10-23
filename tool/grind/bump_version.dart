// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';
import 'dart:convert';

import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

/// A regular expression that matches a version in a pubspec.
final _pubspecVersionRegExp = new RegExp(r'^version: (.*)$', multiLine: true);

/// Adds grinder tasks for bumping package versions.
void addBumpVersionTasks() {
  for (var patch in [false, true]) {
    for (var dev in [true, false]) {
      addTask(GrinderTask(
          'bump-version-${patch ? 'patch' : 'minor'}' + (dev ? '-dev' : ''),
          taskFunction: () => _bumpVersion(patch, dev),
          description: 'Bump the version of all packages to the next '
              '${patch ? 'patch' : 'minor'}${dev ? ' dev' : ''} version'));
    }
  }
}

/// Bumps the current package versions to the next [patch] version, with `-dev`
/// if [dev] is true.
void _bumpVersion(bool patch, bool dev) {
  // Returns the version to which to bump [version].
  Version chooseNextVersion(Version version, SourceSpan span) {
    if (dev) {
      if (patch
          ? version.preRelease.isNotEmpty
          : version.patch == 0 ||
              version.preRelease.length != 1 ||
              version.preRelease.first != "dev") {
        fail(span.message("Version is already pre-release", color: true));
      }
    } else if (version.preRelease.length == 1 &&
        version.preRelease.first == "dev" &&
        (patch || version.patch == 0)) {
      // If it's already a dev version, just mark it stable instead of
      // increasing it.
      return Version(version.major, version.minor, version.patch);
    }

    var nextVersion =
        patch || version.major == 0 ? version.nextPatch : version.nextMinor;
    return Version(nextVersion.major, nextVersion.minor, nextVersion.patch,
        pre: dev ? "dev" : null);
  }

  // Bumps the current version of [pubspec] to the next [patch] version, with
  // `-dev` if [dev] is true.
  void bumpDartVersion(String path) {
    var text = File(path).readAsStringSync();
    var pubspec = loadYaml(text, sourceUrl: p.toUri(path)) as YamlMap;
    var version = chooseNextVersion(Version.parse(pubspec["version"] as String),
        pubspec.nodes["version"]!.span);
    File(path).writeAsStringSync(
        text.replaceFirst(_pubspecVersionRegExp, 'version: $version'));
  }

  bumpDartVersion('pubspec.yaml');
  bumpDartVersion('pkg/sass_api/pubspec.yaml');

  var packageJsonPath = 'pkg/sass-parser/package.json';
  var packageJsonText = File(packageJsonPath).readAsStringSync();
  var packageJson =
      loadYaml(packageJsonText, sourceUrl: p.toUri(packageJsonPath)) as YamlMap;
  var version = chooseNextVersion(
      Version.parse(packageJson["version"] as String),
      packageJson.nodes["version"]!.span);
  File(packageJsonPath).writeAsStringSync(JsonEncoder.withIndent("  ")
          .convert({...packageJson, "version": version.toString()}) +
      "\n");
}
