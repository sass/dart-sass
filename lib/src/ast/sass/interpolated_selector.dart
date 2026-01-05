// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/interpolated_selector.dart';
import 'node.dart';

// Note: this has to be a concrete class so we can expose its accept() function
// to the JS parser.

/// A simple selector before interoplation is resolved.
///
/// Unlike [Selector], this is parsed during the initial stylesheet parse
/// when `parseSelectors: true` is passed to [Stylesheet.parse].
///
/// {@category AST}
abstract base class InterpolatedSelector implements SassNode {
  /// Calls the appropriate visit method on [visitor].
  T accept<T>(InterpolatedSelectorVisitor<T> visitor);
}
