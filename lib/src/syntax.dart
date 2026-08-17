// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;

/// An enum of syntaxes that Sass can parse.
///
/// {@category Compile}
enum Syntax(
  /// The name of the syntax.
  final String _name,
) {
  /// The CSS-superset SCSS syntax.
  scss('SCSS'),

  /// The whitespace-sensitive indented syntax.
  sass('Sass'),

  /// The plain CSS syntax, which disallows special Sass features.
  css('CSS');

  /// Returns the default syntax to use for a file loaded from [path].
  static Syntax forPath(String path) => switch (p.extension(path)) {
    '.sass' => .sass,
    '.css' => .css,
    _ => .scss,
  };

  @override
  String toString() => _name;
}
