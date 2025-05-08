// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';
import 'package:path/path.dart' as p;

import '../../importer/node_package.dart';
import '../extension/class.dart';
import '../utils.dart';

/// The exported `NodePackageImporter` class that can be added to the
/// `importers` option to enable loading `pkg:` URLs from `node_modules`.
extension type JSNodePackageImporter._(JSObject _) implements JSObject {
  static final JSClass<JSNodePackageImporter> jsClass = () {
    var jsClass = JSClass<JSNodePackageImporter>(
      'sass.NodePackageImporter',
      ((JSNodePackageImporter _, [String? entrypointDirectory]) =>
          NodePackageImporter(
            switch ((entrypointDirectory, entrypointFilename)) {
              ((var directory?, _)) => directory,
              (_, var filename?) => p.dirname(filename),
              _ => throw "The Node package importer cannot determine an entry "
                  "point because `require.main.filename` is not defined. Please "
                  "provide an `entryPointDirectory` to the `NodePackageImporter`.",
            },
          )).toJS,
    );
    NodePackageImporter('.').toJS.constructor.injectSuperclass(jsClass);
    return jsClass;
  }();

  NodePackageImporter get toDart => this as NodePackageImporter;
}

extension NodePackageImporterToJS on NodePackageImporter {
  JSNodePackageImporter get toJS => this as JSNodePackageImporter;
}
