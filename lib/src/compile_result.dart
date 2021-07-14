// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_maps/source_maps.dart';

import 'visitor/async_evaluate.dart';
import 'visitor/serialize.dart';

/// The result of compiling a Sass document to CSS, along with metadata about
/// the compilation process.
@sealed
class CompileResult {
  /// The result of evaluating the source file.
  final EvaluateResult _evaluate;

  /// The result of serializing the CSS AST to CSS text.
  final SerializeResult _serialize;

  /// The compiled CSS.
  String get css => _serialize.css;

  /// The source map indicating how the source files map to [css].
  ///
  /// This is `null` if source mapping was disabled for this compilation.
  SingleMapping? get sourceMap => _serialize.sourceMap;

  /// The canonical URLs of all stylesheets loaded during compilation.
  Set<Uri> get loadedUrls => _evaluate.loadedUrls;

  /// @nodoc
  @internal
  CompileResult(this._evaluate, this._serialize);
}
