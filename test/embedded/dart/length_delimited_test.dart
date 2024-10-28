// Copyright 2024 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
library;

import 'package:test/test.dart';

import '../shared/length_delimited.dart';
import '../dart_test.dart';

void main() {
  setUpAll(ensureSnapshotUpToDate);
  sharedTests();
}
