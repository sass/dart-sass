// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_test.dart';

/// The path to the sandbox directory.
///
/// This is only set in tests for which [useSandbox] is active.
String get sandbox => _sandbox;
String _sandbox;

/// Declares a [setUp] function that creates a sandbox diretory and sets it as
/// the default for scheduled_test's directory descriptors.
///
/// This should be called outside of any tests.
void useSandbox() {
  setUp(() {
    _sandbox = Directory.systemTemp.createTempSync("dart-sass-test").path;
    d.defaultRoot = _sandbox;

    currentSchedule.onComplete.schedule(() {
      try {
        new Directory(_sandbox).deleteSync(recursive: true);
      } on IOException catch (_) {
        // Silently swallow exceptions on Windows. If the test failed, there may
        // still be lingering processes that have files in the sandbox open,
        // which will cause this to fail on Windows.
        if (!Platform.isWindows) rethrow;
      }
    }, 'deleting the sandbox directory');
  });
}
