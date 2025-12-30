// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/interpolated_selector.dart';
import '../../selector.dart';
import 'qualified_name.dart';
import 'simple.dart';

/// An type selector.
///
/// Unlike [TypeSelector], this is parsed during the initial stylesheet
/// parse when `parseSelectors: true` is passed to [Stylesheet.parse].
///
/// {@category AST}
final class InterpolatedTypeSelector extends InterpolatedSimpleSelector {
  /// The element name being selected for.
  final InterpolatedQualifiedName name;

  FileSpan get span => name.span;

  /// Creates a type selector that matches any element with a property of
  /// the given name.
  InterpolatedTypeSelector(this.name);

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(InterpolatedSelectorVisitor<T> visitor) =>
      visitor.visitTypeSelector(this);

  String toString() => name.toString();
}
