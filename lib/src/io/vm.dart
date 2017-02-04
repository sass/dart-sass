// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';
import 'dart:io' as io;

import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import '../exception.dart';

export 'dart:io' show exitCode, FileSystemException;

io.Stdout get stderr => io.stderr;

bool get hasTerminal => io.stdout.hasTerminal;

String readFile(String path) {
  var bytes = new io.File(path).readAsBytesSync();

  try {
    return UTF8.decode(bytes);
  } on FormatException {
    var decoded = UTF8.decode(bytes, allowMalformed: true);
    var sourceFile = new SourceFile(decoded, url: p.toUri(path));

    // TODO(nweiz): Use [FormatException.offset] instead when
    // dart-lang/sdk#28293 is fixed.
    for (var i = 0; i < bytes.length; i++) {
      if (decoded.codeUnitAt(i) != 0xFFFD) continue;
      throw new SassException(
          "Invalid UTF-8.", sourceFile.location(i).pointSpan());
    }

    // This should be unreachable, but we'll rethrow the original exception just
    // in case.
    rethrow;
  }
}

bool fileExists(String path) => new io.File(path).existsSync();

bool dirExists(String path) => new io.Directory(path).existsSync();
