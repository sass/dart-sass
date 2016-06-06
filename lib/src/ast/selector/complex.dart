// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../selector.dart';

class ComplexSelector extends Selector {
  final List<ComplexSelectorComponent> components;

  // Indices of [components] that are followed by line breaks.
  final List<int> lineBreaks;

  final FileSpan span;

  ComplexSelector(Iterable<ComplexSelectorComponent> components,
      {Iterable<int> lineBreaks, this.span})
      : components = new List.unmodifiable(components),
        lineBreaks = new List.unmodifiable(lineBreaks);

  String toString() => components.join(" ");
}

abstract class ComplexSelectorComponent {}

class Combinator implements ComplexSelectorComponent {
  static const nextSibling = const Combinator._("+");
  static const child = const Combinator._(">");
  static const followingSibling = const Combinator._("~");

  final String combinator;

  const Combinator._(this.combinator);

  String toString() => combinator;
}


