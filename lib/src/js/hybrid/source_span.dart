// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:web/web.dart';

import '../../util/nullable.dart';
import '../../util/span.dart';

extension SourceSpanToJS on SourceSpan {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    bogusSourceSpan.toJS.constructor.defineGetters({
      'url': (UnsafeDartWrapper<SourceSpan> self) =>
          self.toDart.sourceUrl.andThen(
            (url) =>
                (url.scheme == '' ? p.toUri(p.absolute(p.fromUri(url))) : url)
                    .toJS,
          ),
    });
  }

  UnsafeDartWrapper<SourceSpan> get toJS => toUnsafeWrapper;
}
