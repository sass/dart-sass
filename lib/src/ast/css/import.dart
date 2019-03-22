// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/css.dart';
import 'media_query.dart';
import 'node.dart';
import 'value.dart';

/// A plain CSS `@import`.
abstract class CssImport extends CssNode {
  /// The URL being imported.
  ///
  /// This includes quotes.
  CssValue<String> get url;

  /// The supports condition attached to this import.
  CssValue<String> get supports;

  /// The media query attached to this import.
  List<CssMediaQuery> get media;

  T accept<T>(CssVisitor<T> visitor) => visitor.visitCssImport(this);
}
