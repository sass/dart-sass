// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:scheduled_test/scheduled_process.dart';

import 'cli_shared.dart';

void main() {
  sharedTests((arguments, {workingDirectory}) => new ScheduledProcess.start(
      Platform.executable, <Object>["bin/sass.dart"]..addAll(arguments),
      workingDirectory: workingDirectory, description: "sass"));
}
