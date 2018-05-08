// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:dart2_constant/convert.dart' as convert;
import 'package:test/test.dart';

/// A regular expression for matching the URL in a source map comment.
final _sourceMapCommentRegExp =
    new RegExp(r"/\*# sourceMappingURL=(.*) \*/\s*$");

/// Loads and decodes the source map embedded as a `data:` URI in [css].
///
/// Throws a [TestFailure] if [css] doesn't have such a source map.
Map<String, Object> embeddedSourceMap(String css) {
  expect(css, matches(_sourceMapCommentRegExp));

  var match = _sourceMapCommentRegExp.firstMatch(css);
  var data = Uri.parse(match[1]).data;
  expect(data.mimeType, equals("application/json"));
  return convert.json.decode(data.contentAsString()) as Map<String, Object>;
}
