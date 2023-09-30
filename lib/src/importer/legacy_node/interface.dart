// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

final class NodeImporter {
  NodeImporter(Object options, Iterable<String> includePaths,
      Iterable<Object> importers);

  (String contents, String url)? loadRelative(
          String url, Uri? previous, bool forImport) =>
      throw '';

  (String contents, String url)? load(
          String url, Uri? previous, bool forImport) =>
      throw '';

  Future<(String contents, String url)?> loadAsync(
          String url, Uri? previous, bool forImport) =>
      throw '';
}
