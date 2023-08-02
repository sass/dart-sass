// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'node.dart';
import 'value.dart';

/// A plain CSS `@import`.
abstract interface class CssImport implements CssNode {
  /// The URL being imported.
  ///
  /// This includes quotes.
  CssValue<String> get url;

  /// The modifiers (such as media or supports queries) attached to this import.
  CssValue<String>? get modifiers;
}
