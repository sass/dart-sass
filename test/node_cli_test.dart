// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@Tags(const ['node'])

import 'dart:io';

import 'package:scheduled_test/scheduled_process.dart';
import 'package:scheduled_test/scheduled_test.dart';

import 'cli_shared.dart';

void main() {
  setUpAll(() {
    var grinder = new ScheduledProcess.start(
        Platform.executable, ["tool/grind.dart", "npm_package"]);
    grinder.shouldExit(0);
  });

  sharedTests((arguments, {workingDirectory}) => new ScheduledProcess.start(
      "node", <Object>["build/npm/sass.js"]..addAll(arguments),
      workingDirectory: workingDirectory, description: "sass"));
}
