// Copyright 2025 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
@Tags(['node'])
library;

import 'package:cli_pkg/testing.dart' as pkg;
import 'package:test/test.dart';

import '../ensure_npm_package.dart';
import 'shared/embedded_process.dart';

void main() {}

/// Ensures that the snapshot of the npm package used by [runSassEmbedded] is
/// up-to-date, if one has been generated.
void ensureSnapshotUpToDate() => ensureNpmPackage;

Future<EmbeddedProcess> runSassEmbedded(
        [Iterable<String> args = const Iterable.empty()]) =>
    EmbeddedProcess.start(pkg.executableRunner("sass", node: true),
        [...pkg.executableArgs("sass", node: true), "--embedded", ...args]);
