// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../selector.dart';
import '../../utils.dart';

class CompoundSelector extends Selector implements ComplexSelectorComponent {
  final List<SimpleSelector> components;

  SourceSpan get span => spanForList(components);

  CompoundSelector(Iterable<SimpleSelector> components)
      : components = new List.unmodifiable(components);

  String toString() => components.join("");
}
