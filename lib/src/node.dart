// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'executable.dart' as executable;

@JS()
class _Exports {
  external set run_(function);
}

@JS()
external _Exports get exports;

/// The entrypoint for Node.js.
///
/// This sets up exports that can be called from JS. These include a private
/// export that runs the normal `main()`, which is called from `package/sass.js`
/// to run the executable when installed from NPM.
void main() {
  exports.run_ = allowInterop(executable.main);
}
