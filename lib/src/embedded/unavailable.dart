// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../io.dart';

void main(List<String> args) async {
  stderr.writeln('sass --embedded is unavailable in pure JS mode.');
  exitCode = 1;
}
