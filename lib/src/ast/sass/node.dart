// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../node.dart';

/// A node in the abstract syntax tree for an unevaluated Sass or SCSS file.
///
/// {@category AST}
@sealed
abstract interface class SassNode implements AstNode {}
