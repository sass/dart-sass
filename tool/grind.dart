// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:grinder/grinder.dart';

main(args) => grind(args);

@DefaultTask()
format() {
  Pub.run('dart_style',
      script: 'format',
      arguments: ['--overwrite']
        ..addAll(existingSourceDirs.map((dir) => dir.path)));
}
