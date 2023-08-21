// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
@Tags(['node'])

import 'package:test/test.dart';

import '../../ensure_npm_package.dart';
import '../node_test.dart';
import '../shared/colon_args.dart';

void main() {
  setUpAll(ensureNpmPackage);
  sharedTests(runSass);
}
