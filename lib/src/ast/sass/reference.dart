// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import 'node.dart';

/// A common interface for any node that references a Sass member.
///
/// {@category AST}
@sealed
abstract class SassReference extends SassNode {
  /// The namespace of the member being referenced, or `null` if it's referenced
  /// without a namespace.
  String? get namespace;

  /// The name of the member being referenced, with underscores converted to
  /// hyphens.
  ///
  /// This does not include the `$` for variables.
  String get name;

  /// The span containing this reference's name.
  ///
  /// For variables, this should include the `$`.
  FileSpan get nameSpan;

  /// The span containing this reference's namespace, null if [namespace] is
  /// null.
  FileSpan? get namespaceSpan;
}
