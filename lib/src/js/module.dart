// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

@JS('nodeModule')
external JSModule get module;

/// A Dart API for the [`node:module`] module.
///
/// [`node:module`]: https://nodejs.org/api/module.html#modules-nodemodule-api
@anonymous
extension type JSModule._(JSObject _) implements JSObject {
  /// See https://nodejs.org/api/module.html#modulecreaterequirefilename.
  external JSModuleRequire createRequire(String filename);
}

/// A `require` function returned by `module.createRequire()`.
@anonymous
extension type JSModuleRequire._(JSObject _) implements JSObject {
  /// See https://nodejs.org/api/modules.html#requireresolverequest-options.
  external String resolve(String filename);
}
