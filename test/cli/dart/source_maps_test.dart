// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
library;

import 'package:test/test.dart';

import '../dart_test.dart';
import '../shared/source_maps.dart';

void main() {
  setUpAll(ensureSnapshotUpToDate);
  sharedTests(runSass);
}
