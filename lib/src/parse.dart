// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/sass.dart';
import 'ast/selector.dart';
import 'parse/at_root_query.dart';
import 'parse/scss.dart';
import 'parse/selector.dart';

Stylesheet parseScss(String contents, {url}) =>
    new ScssParser(contents, url: url).parse();

SelectorList parseSelector(String contents, {url}) =>
    new SelectorParser(contents, url: url).parse();

SimpleSelector parseSimpleSelector(String contents, {url}) =>
    new SelectorParser(contents, url: url).parseSimpleSelector();

AtRootQuery parseAtRootQuery(String contents, {url}) =>
    new AtRootQueryParser(contents, url: url).parse();
