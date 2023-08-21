// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// OS X's modification time reporting is flaky, so we skip these tests on it.
@TestOn('vm && !mac-os')

// File watching is inherently flaky at the OS level. To mitigate this, we do a
// few retries when the tests fail.
@Retry(3)

import 'package:test/test.dart';

import '../dart_test.dart';
import '../shared/watch.dart';

void main() {
  setUpAll(ensureSnapshotUpToDate);
  sharedTests(runSass);
}
