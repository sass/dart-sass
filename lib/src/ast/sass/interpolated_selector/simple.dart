// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../interpolated_selector.dart';

/// A simple selector before interoplation is resolved.
///
/// Unlike [SimpleSelector], this is parsed during the initial stylesheet parse
/// when `parseSelectors: true` is passed to [Stylesheet.parse].
///
/// {@category AST}
abstract base class InterpolatedSimpleSelector extends InterpolatedSelector {}
