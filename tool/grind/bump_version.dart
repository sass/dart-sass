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
final _pubspecVersionRegExp = RegExp(r'^version: (.*)$', multiLine: true);

/// A regular expression that matches a Sass dependency version in a pubspec.
final _sassVersionRegExp = RegExp(r'^( +)sass: (\d.*)$', multiLine: true);

/// Adds grinder tasks for bumping package versions.
void addBumpVersionTasks() {
  for (var patch in [false, true]) {
    for (var dev in [true, false]) {
      addTask(
        GrinderTask(
          'bump-version-${patch ? 'patch' : 'minor'}' + (dev ? '-dev' : ''),
          taskFunction: () => _bumpVersion(patch, dev),
          description: 'Bump the version of all packages to the next '
              '${patch ? 'patch' : 'minor'}${dev ? ' dev' : ''} version',
        ),
      );
    }
  }
}

/// Bumps the current package versions to the next [patch] version, with `-dev`
/// if [dev] is true.
void _bumpVersion(bool patch, bool dev) {
  // Returns the version to which to bump [version].
  Version chooseNextVersion(Version version, SourceSpan span) {
    if (dev) {
      if (version.preRelease.isNotEmpty && (patch || version.patch == 0)) {
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
    return Version(
      nextVersion.major,
      nextVersion.minor,
      nextVersion.patch,
      pre: dev ? "dev" : null,
    );
  }

  /// Adds a "No user-visible changes" entry for [version] to the changelog in
  /// [dir].
  void addChangelogEntry(String dir, Version version) {
    var path = p.join(dir, "CHANGELOG.md");
    var text = File(path).readAsStringSync();
    if (!dev && text.startsWith("## $version-dev\n")) {
      File(path).writeAsStringSync(
        text.replaceFirst("## $version-dev\n", "## $version\n"),
      );
    } else if (text.startsWith("## $version\n")) {
      return;
    } else {
      File(
        path,
      ).writeAsStringSync("## $version\n\n* No user-visible changes.\n\n$text");
    }
  }

  // Bumps the current version of [pubspec] to the next [patch] version, with
  // `-dev` if [dev] is true.
  //
  // If [sassVersion] is passed, this bumps the `sass` dependency to that version.
  //
  // Returns the new version of this package.
  Version bumpDartVersion(String path, [Version? sassVersion]) {
    var text = File(path).readAsStringSync();
    var pubspec = loadYaml(text, sourceUrl: p.toUri(path)) as YamlMap;
    var version = chooseNextVersion(
      Version.parse(pubspec["version"] as String),
      pubspec.nodes["version"]!.span,
    );

    text = text.replaceFirst(_pubspecVersionRegExp, 'version: $version');
    if (sassVersion != null) {
      // Don't depend on a prerelease version, depend on its released
      // equivalent.
      var sassDependencyVersion = Version(
        sassVersion.major,
        sassVersion.minor,
        sassVersion.patch,
      );
      text = text.replaceFirstMapped(
        _sassVersionRegExp,
        (match) => '${match[1]}sass: $sassDependencyVersion',
      );
    }

    File(path).writeAsStringSync(text);
    addChangelogEntry(p.dirname(path), version);
    return version;
  }

  var sassVersion = bumpDartVersion('pubspec.yaml');
  bumpDartVersion('pkg/sass_api/pubspec.yaml', sassVersion);

  var packageJsonPath = 'pkg/sass-parser/package.json';
  var packageJsonText = File(packageJsonPath).readAsStringSync();
  var packageJson =
      loadYaml(packageJsonText, sourceUrl: p.toUri(packageJsonPath)) as YamlMap;
  var version = chooseNextVersion(
    Version.parse(packageJson["version"] as String),
    packageJson.nodes["version"]!.span,
  );
  File(packageJsonPath).writeAsStringSync(
    JsonEncoder.withIndent(
          "  ",
        ).convert({...packageJson, "version": version.toString()}) +
        "\n",
  );
  addChangelogEntry("pkg/sass-parser", version);
}
