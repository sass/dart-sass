// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS('nodeModule')
external JSModule get module;

/// A Dart API for the [`node:module`] module.
///
/// [`node:module`]: https://nodejs.org/api/module.html#modules-nodemodule-api
@JS()
@anonymous
class JSModule {
  /// See https://nodejs.org/api/module.html#modulecreaterequirefilename.
  external JSModuleRequire createRequire(String filename);
}

/// A `require` function returned by `module.createRequire()`.
@JS()
@anonymous
class JSModuleRequire {
  /// See https://nodejs.org/api/modules.html#requireresolverequest-options.
  external String resolve(String filename);
}
