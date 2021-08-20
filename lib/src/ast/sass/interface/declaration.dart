// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../node.dart';

/// A common interface any node that declares a Sass member.
///
/// {@category AST}
@sealed
abstract class SassDeclaration extends SassNode {
  /// The name of the declaration, with underscores converted to hyphens.
  ///
  /// This does not include the `$` for variables.
  String get name;

  /// The span containing this declaration's name.
  ///
  /// This includes the `$` for variables.
  FileSpan get nameSpan;
}
