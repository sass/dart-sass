// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: implementation_imports

import 'package:sass/src/parse/parser.dart';

export 'package:sass/sass.dart';
export 'package:sass/src/ast/node.dart';
export 'package:sass/src/ast/sass.dart' hide AtRootQuery;
export 'package:sass/src/ast/selector.dart';
export 'package:sass/src/async_import_cache.dart';
export 'package:sass/src/exception.dart' show SassFormatException;
export 'package:sass/src/import_cache.dart';
export 'package:sass/src/importer/node_package.dart';
export 'package:sass/src/interpolation_map.dart';
export 'package:sass/src/value.dart' hide ColorFormat, SpanColorFormat;
export 'package:sass/src/visitor/find_dependencies.dart';
export 'package:sass/src/visitor/interface/expression.dart';
export 'package:sass/src/visitor/interface/selector.dart';
export 'package:sass/src/visitor/interface/statement.dart';
export 'package:sass/src/visitor/ast_search.dart';
export 'package:sass/src/visitor/recursive_ast.dart';
export 'package:sass/src/visitor/recursive_selector.dart';
export 'package:sass/src/visitor/recursive_statement.dart';
export 'package:sass/src/visitor/replace_expression.dart';
export 'package:sass/src/visitor/selector_search.dart';
export 'package:sass/src/visitor/statement_search.dart';

/// Parses [text] as a CSS identifier and returns the result.
///
/// Throws a [SassFormatException] if parsing fails.
///
/// {@category Parsing}
String parseIdentifier(String text) => Parser.parseIdentifier(text);

/// Returns whether [text] is a valid CSS identifier.
///
/// {@category Parsing}
bool isIdentifier(String text) => Parser.isIdentifier(text);
