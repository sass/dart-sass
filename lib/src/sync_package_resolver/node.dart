// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class SyncPackageResolver {
  static final _error =
      UnsupportedError('SyncPackageResolver is not supported in JS.');

  static Future<SyncPackageResolver> get current => throw _error;

  Uri resolveUri(Object packageUri) => throw _error;

  factory SyncPackageResolver.config(Map<String, Uri> configMap) =>
      throw _error;
}
