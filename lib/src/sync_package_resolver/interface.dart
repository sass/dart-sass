// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

abstract class SyncPackageResolver {
  Map<String, Uri> get packageConfigMap;

  Uri get packageConfigUri;

  Uri get packageRoot;

  String get processArgument;

  static final Future<SyncPackageResolver> current = null;

  Uri resolveUri(packageUri);

  Uri urlFor(String package, [String path]);

  Uri packageUriFor(url);

  String packagePath(String package);
}
