// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../importer.dart';

/// An importer that throws an error and never imports any stylesheets.
///
/// This is used for as a default importer in browser contexts,
/// where custom user-supplied importers are required.
class BrowserImporter extends Importer {
  Uri? canonicalize(Uri url) {
    throwError();
    return null;
  }

  ImporterResult? load(Uri url) {
    throwError();
    return null;
  }

  bool couldCanonicalize(Uri url, Uri canonicalUrl) => false;
}

void throwError() {
  throw "Custom importers are required to `@use` or `@import` when compiling in the browser.";
}
