// Copyright 2025 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
library;

import 'package:test/test.dart';

import '../shared/protocol.dart';
import '../dart_test.dart';

void main() {
  setUpAll(ensureSnapshotUpToDate);
  sharedTests(runSassEmbedded);
}
