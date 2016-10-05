// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

class Stderr {
  void write(object) {}
  void writeln([object]) {}
  void flush() {}
}

Stderr get stderr => null;

List<String> getArguments(List<String> mainArguments) => null;

String readFile(String path) => null;

bool fileExists(String path) => null;

void exit(int exitCode) {}
