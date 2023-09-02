// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:isolate';

import 'package:term_glyph/term_glyph.dart' as term_glyph;

import '../options.dart';
import '../../stylesheet_graph.dart';
import 'js.dart' as c;

/// Compiles the stylesheet at [source] to [destination].
///
/// Runs in a new Dart Isolate, unless [source] is `null`.
Future<(int, String, String?)?> compileStylesheet(ExecutableOptions options,
    StylesheetGraph graph, String? source, String? destination,
    {bool ifModified = false}) async {
  // Reading from stdin does not work properly in dart isolate.
  if (source == null) {
    return c.compileStylesheet(options, graph, source, destination,
        ifModified: ifModified);
  }

  return Isolate.run(() {
    term_glyph.ascii = !options.unicode;
    return c.compileStylesheet(options, graph, source, destination,
        ifModified: ifModified);
  });
}
