// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../sass/interpolation.dart';
import '../../selector.dart';
import '../node.dart';

/// A component of a [InterpolatedComplexSelector].
///
/// Unlike [ComplexSelectorComponent], this is parsed during the initial
/// stylesheet parse when `parseSelectors: true` is passed to
/// [Stylesheet.parse].
///
/// {@category AST}
final class InterpolatedQualifiedName implements SassNode {
  /// The identifier name.
  final Interpolation name;

  final FileSpan span;

  /// The namespace name.
  final Interpolation? namespace;

  /// Creates an attribute selector that matches any element with a property of
  /// the given name.
  InterpolatedQualifiedName(this.name, this.span, {this.namespace});

  String toString() => switch (namespace) {
        var namespace? => '$namespace|$name',
        _ => name.toString()
      };
}
