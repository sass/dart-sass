// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// A class selector.
///
/// This selects elements whose `class` attribute contains an identifier with
/// the given name.
///
/// {@category AST}
@sealed
class ClassSelector extends SimpleSelector {
  /// The class name this selects for.
  final String name;

  ClassSelector(this.name, FileSpan span) : super(span);

  bool operator ==(Object other) =>
      other is ClassSelector && other.name == name;

  T accept<T>(SelectorVisitor<T> visitor) => visitor.visitClassSelector(this);

  /// @nodoc
  @internal
  ClassSelector addSuffix(String suffix) => ClassSelector(name + suffix, span);

  int get hashCode => name.hashCode;
}
