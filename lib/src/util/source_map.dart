// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_maps/source_maps.dart';

import '../source_map_include_sources.dart';

Map<String, dynamic> sourceMapToJson(SingleMapping sourceMap,
    {required SourceMapIncludeSources sourceMapIncludeSources}) {
  if (sourceMapIncludeSources == SourceMapIncludeSources.true_) {
    sourceMapIncludeSources = SourceMapIncludeSources.always;
  } else if (sourceMapIncludeSources == SourceMapIncludeSources.false_) {
    sourceMapIncludeSources = SourceMapIncludeSources.never;
  }
  return sourceMap.toJson(
      includeSourceContents:
          sourceMapIncludeSources == SourceMapIncludeSources.always ||
              (sourceMapIncludeSources == SourceMapIncludeSources.auto &&
                  sourceMap.files.any((file) => file != null)));
}
