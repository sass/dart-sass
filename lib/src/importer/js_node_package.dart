// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/// The JS [NodePackageImporter] class that can be added to the
/// `importers` option to enable loading `pkg:` URLs from `node_modules`.
class JSNodePackageImporter {
  final String? entryPointPath;

  JSNodePackageImporter(this.entryPointPath);
}
