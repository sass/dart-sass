// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io' as io;

io.Stdout get stderr => io.stderr;

List<String> getArguments(List<String> mainArguments) => mainArguments;

String readFile(String path) => new io.File(path).readAsStringSync();

bool fileExists(String path) => new io.File(path).existsSync();

void exit(int exitCode) => io.exit(exitCode);
