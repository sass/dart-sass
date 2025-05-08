// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:web/web.dart';

import '../../util/lazy_file_span.dart';
import '../../util/multi_span.dart';
import '../../util/nullable.dart';
import '../../util/span.dart';
import 'file_location.dart';

extension type JSFileSpan._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    for (var span in [
      bogusSpan,
      MultiSpan(bogusSpan, '', const {}),
      LazyFileSpan(() => bogusSpan)
    ]) {
      span.toJS.constructor.defineGetters({
        'start': (JSFileSpan self) => self.toDart.start.toJS,
        'end': (JSFileSpan self) => self.toDart.end.toJS,
        'url': (JSFileSpan self) => self.toDart.sourceUrl.andThen(
              (url) =>
                  (url.scheme == '' ? p.toUri(p.absolute(p.fromUri(url))) : url)
                      .toJS,
            ),
        'text': (JSFileSpan self) => self.toDart.text.toJS,
        'context': (JSFileSpan self) => self.toDart.context.toJS,
      });
    }
  }

  FileSpan get toDart => this as FileSpan;
}

extension FileSpanToJS on FileSpan {
  JSFileSpan get toJS => this as JSFileSpan;
}
