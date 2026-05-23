// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_maps/source_maps.dart';

import '../source_map_include_sources.dart';

/// Returns a JSON map for the SingleMapping sourceMap.
///
/// The returned JSON map includes a `sourcesContent` array only if one or more
/// source content is included.
Map<String, dynamic> sourceMapToJson(SingleMapping sourceMap,
    {required SourceMapIncludeSources sourceMapIncludeSources}) {
  // TODO: remove support for deprecated boolean option.
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
