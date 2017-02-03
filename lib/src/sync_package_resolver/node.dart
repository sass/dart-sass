// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

class SyncPackageResolver {
  static final _error =
      new UnsupportedError('SyncPackageResolver is not supported in JS.');

  static Future<SyncPackageResolver> get current => throw _error;

  Uri resolveUri(packageUri) => throw _error;

  factory SyncPackageResolver.config(Map<String, Uri> configMap) =>
      throw _error;
}
