// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:tuple/tuple.dart';

class NodeImporter {
  NodeImporter(Object options, Iterable<String> includePaths,
      Iterable<Object> importers);

  Tuple2<String, String>? loadRelative(
          String url, Uri? previous, bool forImport) =>
      throw '';

  Tuple2<String, String>? load(String url, Uri? previous, bool forImport) =>
      throw '';

  Future<Tuple2<String, String>?> loadAsync(
          String url, Uri? previous, bool forImport) =>
      throw '';
}
