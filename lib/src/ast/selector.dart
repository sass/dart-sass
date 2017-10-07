// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../visitor/interface/selector.dart';
import '../visitor/serialize.dart';

export 'selector/attribute.dart';
export 'selector/class.dart';
export 'selector/complex.dart';
export 'selector/compound.dart';
export 'selector/id.dart';
export 'selector/list.dart';
export 'selector/parent.dart';
export 'selector/placeholder.dart';
export 'selector/pseudo.dart';
export 'selector/qualified_name.dart';
export 'selector/simple.dart';
export 'selector/type.dart';
export 'selector/universal.dart';

/// A node in the abstract syntax tree for a selector.
///
/// This selector tree is mostly plain CSS, but also may contain a
/// [ParentSelector] or a [PlaceholderSelector].
///
/// Selectors have structural equality semantics.
abstract class Selector {
  /// Whether this selector, and complex selectors containing it, should not be
  /// emitted.
  bool get isInvisible => false;

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(SelectorVisitor<T> visitor);

  String toString() => serializeSelector(this, inspect: true);
}
