// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'url.dart';

@JS()
@anonymous
class JSImporter {
  external Object? Function(String, CanonicalizeContext)? get canonicalize;
  external Object? Function(JSUrl)? get load;
  external Object? Function(String, CanonicalizeContext)? get findFileUrl;
  external Object? get nonCanonicalScheme;
}

@JS()
@anonymous
class CanonicalizeContext {
  external bool get fromImport;
  external JSUrl? get containingUrl;

  external factory CanonicalizeContext({bool fromImport, JSUrl? containingUrl});
}

@JS()
@anonymous
class JSImporterResult {
  external String? get contents;
  external String? get syntax;
  external JSUrl? get sourceMapUrl;
}
