// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:tuple/tuple.dart';

class NodeImporter {
  NodeImporter(
      Object context, Iterable<String> includePaths, Iterable importers);

  Tuple2<String, String> load(String url, Uri previous) => null;

  Future<Tuple2<String, String>> loadAsync(String url, Uri previous) => null;
}
