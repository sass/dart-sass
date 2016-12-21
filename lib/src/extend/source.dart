// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../ast/selector.dart';

/// The source of an `@extend` declaration.
class ExtendSource {
  /// The selector for the style rule in which this `@extend` was declared.
  final SelectorList extender;

  /// The span for the `@extend` rule that declared this extension.
  final FileSpan span;

  /// Whether this extension matched a selector, or was marked optional.
  var isUsed = false;

  ExtendSource(this.extender, this.span);

  int get hashCode => extender.hashCode;

  bool operator ==(Object other) =>
      other is ExtendSource && other.extender == extender;
}
