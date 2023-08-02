// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// OS X's modification time reporting is flaky, so we skip these tests on it.
@TestOn('vm && !mac-os')
@Tags(['node'])

import 'package:test/test.dart';

import '../../ensure_npm_package.dart';
import '../node_test.dart';
import '../shared/update.dart';

void main() {
  setUpAll(ensureNpmPackage);
  sharedTests(runSass);
}
