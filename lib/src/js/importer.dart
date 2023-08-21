// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'url.dart';

@JS()
@anonymous
class NodeImporter {
  external Object? Function(String, CanonicalizeOptions)? get canonicalize;
  external Object? Function(JSUrl)? get load;
  external Object? Function(String, CanonicalizeOptions)? get findFileUrl;
}

@JS()
@anonymous
class CanonicalizeOptions {
  external bool get fromImport;

  external factory CanonicalizeOptions({bool fromImport});
}

@JS()
@anonymous
class NodeImporterResult {
  external String? get contents;
  external String? get syntax;
  external JSUrl? get sourceMapUrl;
}
