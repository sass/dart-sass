#!/usr/bin/env dart
// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

main() async {
  var sources = new Directory("benchmark/source");
  if (!await sources.exists()) await sources.create();

  await writeNTimes("${sources.path}/small_plain.scss", ".foo {a: b}", 4);
  await writeNTimes(
      "${sources.path}/large_plain.scss", ".foo {a: b}", math.pow(2, 17));
  await writeNTimes("${sources.path}/preceding_sparse_extend.scss",
      ".foo {a: b}", math.pow(2, 17),
      header: '.x {@extend .y}', footer: '.y {a: b}');
  await writeNTimes("${sources.path}/following_sparse_extend.scss",
      ".foo {a: b}", math.pow(2, 17),
      header: '.y {a: b}', footer: '.x {@extend .y}');
  await writeNTimes("${sources.path}/preceding_dense_extend.scss",
      ".foo {a: b}", math.pow(2, 17),
      header: '.bar {@extend .foo}');
  await writeNTimes("${sources.path}/following_dense_extend.scss",
      ".foo {a: b}", math.pow(2, 17),
      footer: '.bar {@extend .foo}');
}

Future writeNTimes(String path, String text, num times,
    {String header, String footer}) async {
  print("Generating $path...");
  var file = new File(path).openWrite();
  if (header != null) file.writeln(header);
  for (var i = 0; i < times; i++) {
    file.writeln(text);
  }
  if (footer != null) file.writeln(footer);
  await file.close();
}
