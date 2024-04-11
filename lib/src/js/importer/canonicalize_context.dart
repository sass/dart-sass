// Copyright 2014 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../importer/canonicalize_context.dart';
import '../url.dart';
import '../../util/nullable.dart';
import '../utils.dart';

@JSExport()
class JSExportCanonicalizeContext {
  final CanonicalizeContext _canonicalizeContext;

  bool get fromImport => _canonicalizeContext.fromImport;
  JSUrl? get containingUrl =>
      _canonicalizeContext.containingUrl.andThen(dartToJSUrl);

  JSExportCanonicalizeContext(this._canonicalizeContext);
}
