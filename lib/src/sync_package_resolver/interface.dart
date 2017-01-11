// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

abstract class SyncPackageResolver {
  static final Future<SyncPackageResolver> current = null;

  Uri resolveUri(packageUri);

  factory SyncPackageResolver.config(Map<String, Uri> configMap) => null;
}
