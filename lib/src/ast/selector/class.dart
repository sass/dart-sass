// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// A class selector.
///
/// This selects elements whose `class` attribute contains an identifier with
/// the given name.
///
/// {@category AST}
final class ClassSelector(
  /// The class name this selects for.
  final String name,
  super.span,
) extends SimpleSelector {
  @override
  bool operator ==(Object other) =>
      other is ClassSelector && other.name == name;

  @override
  T accept<T>(SelectorVisitor<T> visitor) => visitor.visitClassSelector(this);

  /// @nodoc
  @override
  @internal
  ClassSelector addSuffix(String suffix) => ClassSelector(name + suffix, span);

  @override
  int get hashCode => name.hashCode;
}
