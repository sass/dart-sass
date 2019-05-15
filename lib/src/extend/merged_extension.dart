// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../exception.dart';
import '../utils.dart';
import 'extension.dart';

/// An [Extension] created by merging two [Extension]s with the same extender
/// and target.
///
/// This is used when multiple mandatory extensions exist to ensure that both of
/// them are marked as resolved.
class MergedExtension extends Extension {
  /// One of the merged extensions.
  final Extension left;

  /// The other merged extension.
  final Extension right;

  /// Returns an extension that combines [left] and [right].
  ///
  /// Throws a [SassException] if [left] and [right] have incompatible media
  /// contexts.
  ///
  /// Throws an [ArgumentError] if [left] and [right] don't have the same
  /// extender and target.
  static Extension merge(Extension left, Extension right) {
    if (left.extender != right.extender || left.target != right.target) {
      throw ArgumentError("$left and $right aren't the same extension.");
    }

    if (left.mediaContext != null &&
        right.mediaContext != null &&
        !listEquals(left.mediaContext, right.mediaContext)) {
      throw SassException(
          "From ${left.span.message('')}\n"
          "You may not @extend the same selector from within different media "
          "queries.",
          right.span);
    }

    // If one extension is optional and doesn't add a special media context, it
    // doesn't need to be merged.
    if (right.isOptional && right.mediaContext == null) return left;
    if (left.isOptional && left.mediaContext == null) return right;

    return MergedExtension._(left, right);
  }

  MergedExtension._(this.left, this.right)
      : super(left.extender, left.target, left.extenderSpan, left.span,
            left.mediaContext ?? right.mediaContext,
            specificity: left.specificity, optional: true);

  /// Returns all leaf-node [Extension]s in the tree or [MergedExtension]s.
  Iterable<Extension> unmerge() sync* {
    if (left is MergedExtension) {
      yield* (left as MergedExtension).unmerge();
    } else {
      yield left;
    }

    if (right is MergedExtension) {
      yield* (right as MergedExtension).unmerge();
    } else {
      yield right;
    }
  }
}
