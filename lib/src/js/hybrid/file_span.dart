// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:web/web.dart';

import '../../util/lazy_file_span.dart';
import '../../util/multi_span.dart';
import '../../util/nullable.dart';
import '../../util/span.dart';
import 'file_location.dart';

extension FileSpanToJS on FileSpan {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    for (var span in [
      bogusSpan,
      MultiSpan(bogusSpan, '', const {}),
      LazyFileSpan(() => bogusSpan)
    ]) {
      span.toJS.constructor.defineGetters({
        'start': (UnsafeDartWrapper<FileSpan> self) => self.toDart.start.toJS,
        'end': (UnsafeDartWrapper<FileSpan> self) => self.toDart.end.toJS,
        'url': (UnsafeDartWrapper<FileSpan> self) =>
            self.toDart.sourceUrl.andThen(
              (url) =>
                  (url.scheme == '' ? p.toUri(p.absolute(p.fromUri(url))) : url)
                      .toJS,
            ),
        'text': (UnsafeDartWrapper<FileSpan> self) => self.toDart.text.toJS,
        'context': (UnsafeDartWrapper<FileSpan> self) =>
            self.toDart.context.toJS,
      });
    }
  }

  UnsafeDartWrapper<FileSpan> get toJS => toUnsafeWrapper;
}
