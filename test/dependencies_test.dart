// Copyright 2022 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

/// This package's pubspec.
var _pubspec = Pubspec.parse(File('pubspec.yaml').readAsStringSync(),
    sourceUrl: Uri.parse('pubspec.yaml'));

void main() {
  // Assert that our declared dependency on Dart Sass is either a Git dependency
  // or the same version as the version we're testing against.

  test('depends on a compatible version of Dart Sass', () {
    var sassDependency = _pubspec.dependencies['sass'];
    if (sassDependency is GitDependency) return;

    var actualVersion =
        (Process.runSync('dart', ['run', 'sass', '--version']).stdout as String)
            .trim();
    expect(sassDependency, isA<HostedDependency>());
    expect(actualVersion,
        equals((sassDependency as HostedDependency).version.toString()));
  });
}
