// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:node_interop/js.dart';

import '../js/utils.dart';

/// The JS [NodePackageImporter] class that can be added to the
/// `importers` option to enable loading `pkg:` URLs from `node_modules`.
class JSNodePackageImporter {
  final String? entryPointPath;

  JSNodePackageImporter(this.entryPointPath);
}

Never throwMissingFileSystem() {
  jsThrow(JsError(
      "The Node package importer cannot be used without a filesystem."));
}

Never throwMissingEntryPointPath() {
  jsThrow(JsError("The Node package importer cannot determine an entry point "
      "because `require.main.filename` is not defined. "
      "Please provide an `entryPointPath` to the `NodePackageImporter`."));
}
