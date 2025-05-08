// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:node_interop/module.dart';
import 'package:node_interop/node_interop.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart';

import '../syntax.dart';
import '../utils.dart';
import '../util/map.dart';
import '../value.dart';
import 'array.dart';
import 'function.dart';
import 'module.dart';
import 'reflection.dart';
import 'url.dart';

/// Converts a JavaScript separator string into a [ListSeparator].
ListSeparator parseSeparator(String? separator) => switch (separator) {
      ' ' => ListSeparator.space,
      ',' => ListSeparator.comma,
      '/' => ListSeparator.slash,
      null => ListSeparator.undecided,
      _ => jsThrow(JsError('Unknown separator "$separator".')),
    };

/// Converts a syntax string to an instance of [Syntax].
Syntax parseSyntax(String? syntax) => switch (syntax) {
      null || 'scss' => Syntax.scss,
      'indented' => Syntax.sass,
      'css' => Syntax.css,
      _ => JSError.throwLikeJS(JSError('Unknown syntax "$syntax".')),
    };

/// The path to the Node.js entrypoint, if one can be located.
String? get entrypointFilename {
  if (requireNamespace.main?.filename case var filename?) {
    return filename;
  } else if (process.argv case [_, String path, ...]) {
    return moduleModule.createRequireNamespace(path).resolve(path);
  } else {
    return null;
  }
}
