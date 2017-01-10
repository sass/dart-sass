// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

class SyncPackageResolver {
  Map<String, Uri> get packageConfigMap =>
      throw new UnsupportedError('not implemented for node');

  Uri get packageConfigUri =>
      throw new UnsupportedError('not implemented for node');

  Uri get packageRoot => throw new UnsupportedError('not implemented for node');

  String get processArgument =>
      throw new UnsupportedError('not implemented for node');

  static final Future<SyncPackageResolver> current = null;

  Uri resolveUri(packageUri) =>
      throw new UnsupportedError('not implemented for node');

  Uri urlFor(String package, [String path]) =>
      throw new UnsupportedError('not implemented for node');

  Uri packageUriFor(url) =>
      throw new UnsupportedError('not implemented for node');

  String packagePath(String package) =>
      throw new UnsupportedError('not implemented for node');
}
