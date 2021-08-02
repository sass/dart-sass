// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import 'node.dart';

/// An abstract superclass for different types of import.
///
/// {@category AST}
@sealed
abstract class Import implements SassNode {}
