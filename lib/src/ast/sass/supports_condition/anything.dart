// Copyright 2020 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:meta/meta.dart';

import '../../../interpolation_buffer.dart';
import '../../../util/span.dart';
import '../interpolation.dart';
import '../supports_condition.dart';

/// A supports condition that represents the forwards-compatible
/// `<general-enclosed>` production.
///
/// {@category AST}
final class SupportsAnything implements SupportsCondition {
  /// The contents of the condition.
  final Interpolation contents;

  final FileSpan span;

  SupportsAnything(this.contents, this.span);

  /// @nodoc
  @internal
  Interpolation toInterpolation() => (InterpolationBuffer()
        ..write(span.before(contents.span).text)
        ..addInterpolation(contents)
        ..write(span.after(contents.span).text))
      .interpolation(span);

  /// @nodoc
  @internal
  SupportsAnything withSpan(FileSpan span) => SupportsAnything(contents, span);

  String toString() => "($contents)";
}
