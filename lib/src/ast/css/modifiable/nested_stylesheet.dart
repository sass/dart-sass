// Copyright 2021 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'node.dart';
import 'stylesheet.dart';

/// A [ModifiableCssStylesheet] that also keeps track of a parent node it was
/// loaded into via a nested import.
class ModifiableNestedCssStylesheet extends ModifiableCssStylesheet {
  /// The parent of the nested import that loaded this stylesheet.
  final ModifiableCssParentNode outerParent;

  ModifiableNestedCssStylesheet(this.outerParent, FileSpan span) : super(span);

  ModifiableNestedCssStylesheet copyWithoutChildren() =>
      ModifiableNestedCssStylesheet(outerParent, span);
}
