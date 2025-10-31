// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/interpolated_selector.dart';
import '../../sass/interpolation.dart';
import '../../selector.dart';
import 'simple.dart';

/// An ID selector.
///
/// Unlike [IDSelector], this is parsed during the initial stylesheet parse when
/// `parseSelectors: true` is passed to [Stylesheet.parse].
///
/// {@category AST}
final class InterpolatedIDSelector implements InterpolatedSimpleSelector {
  /// The id name this selects for.
  final Interpolation name;

  FileSpan get span =>
      name.span.file.span(name.span.start.offset - 1, name.span.end.offset);

  InterpolatedIDSelector(this.name);

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(InterpolatedSelectorVisitor<T> visitor) =>
      visitor.visitIDSelector(this);
}
