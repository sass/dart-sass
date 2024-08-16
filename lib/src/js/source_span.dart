// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import '../util/lazy_file_span.dart';
import '../util/multi_span.dart';
import '../util/nullable.dart';
import 'reflection.dart';
import 'utils.dart';

/// Modifies the prototype of the `SourceFile` and `SourceLocation` classes so
/// that they match the JS API.
void updateSourceSpanPrototype() {
  var span = SourceFile.fromString('').span(0);
  var multiSpan = MultiSpan(span, '', {});
  var lazySpan = LazyFileSpan(() => span);

  for (var item in [span, multiSpan, lazySpan]) {
    getJSClass(item).defineGetters({
      'start': (FileSpan span) => span.start,
      'end': (FileSpan span) => span.end,
      'url': (FileSpan span) => span.sourceUrl.andThen((url) => dartToJSUrl(
          url.scheme == '' ? p.toUri(p.absolute(p.fromUri(url))) : url)),
      'text': (FileSpan span) => span.text,
      'context': (FileSpan span) => span.context,
    });
  }

  // Offset is already accessible from JS because it's defined as a field rather
  // than a getter.
  getJSClass(span.start).defineGetters({
    'line': (SourceLocation location) => location.line,
    'column': (SourceLocation location) => location.column,
  });
}
