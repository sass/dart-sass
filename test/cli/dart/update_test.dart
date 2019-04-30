// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// OS X's modification time reporting is flaky, so we skip these tests on it.
@TestOn('vm && !mac-os')

import 'package:test/test.dart';

import '../dart_test.dart';
import '../shared/update.dart';

void main() {
  setUpAll(ensureSnapshotUpToDate);
  sharedTests(runSass);
}
