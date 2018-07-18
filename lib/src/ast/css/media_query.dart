// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../logger.dart';
import '../../parse/media_query.dart';
import '../../utils.dart';

/// A plain CSS media query, as used in `@media` and `@import`.
class CssMediaQuery {
  /// The modifier, probably either "not" or "only".
  ///
  /// This may be `null` if no modifier is in use.
  final String modifier;

  /// The media type, for example "screen" or "print".
  ///
  /// This may be `null`. If so, [features] will not be empty.
  final String type;

  /// Feature queries, including parentheses.
  final List<String> features;

  /// Whether this media query only specifies features.
  bool get isCondition => modifier == null && type == null;

  /// Parses a media query from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  static List<CssMediaQuery> parseList(String contents, {url, Logger logger}) =>
      new MediaQueryParser(contents, url: url, logger: logger).parse();

  /// Creates a media query specifies a type and, optionally, features.
  CssMediaQuery(this.type, {this.modifier, Iterable<String> features})
      : features =
            features == null ? const [] : new List.unmodifiable(features);

  /// Creates a media query that only specifies features.
  CssMediaQuery.condition(Iterable<String> features)
      : modifier = null,
        type = null,
        features = new List.unmodifiable(features);

  /// Merges this with [other] to return a query that matches the intersection
  /// of both inputs.
  MediaQueryMergeResult merge(CssMediaQuery other) {
    var ourModifier = this.modifier?.toLowerCase();
    var ourType = this.type?.toLowerCase();
    var theirModifier = other.modifier?.toLowerCase();
    var theirType = other.type?.toLowerCase();

    if (ourType == null && theirType == null) {
      return new MediaQuerySuccessfulMergeResult._(new CssMediaQuery.condition(
          this.features.toList()..addAll(other.features)));
    }

    String modifier;
    String type;
    List<String> features;
    if ((ourModifier == 'not') != (theirModifier == 'not')) {
      if (ourType == theirType) {
        var negativeFeatures =
            ourModifier == 'not' ? this.features : other.features;
        var positiveFeatures =
            ourModifier == 'not' ? other.features : this.features;

        // If the negative features are a subset of the positive features, the
        // query is empty. For example, `not screen and (color)` has no
        // intersection with `screen and (color) and (grid)`.
        //
        // However, `not screen and (color)` *does* intersect with `screen and
        // (grid)`, because it means `not (screen and (color))` and so it allows
        // a screen with no color but with a grid.
        if (negativeFeatures.every(positiveFeatures.contains)) {
          return MediaQueryMergeResult.empty;
        } else {
          return MediaQueryMergeResult.unrepresentable;
        }
      } else if (ourType == null || theirType == null) {
        return MediaQueryMergeResult.unrepresentable;
      }

      if (ourModifier == 'not') {
        modifier = theirModifier;
        type = theirType;
        features = other.features;
      } else {
        modifier = ourModifier;
        type = ourType;
        features = this.features;
      }
    } else if (ourModifier == 'not') {
      assert(theirModifier == 'not');
      // CSS has no way of representing "neither screen nor print".
      if (ourType != theirType) return MediaQueryMergeResult.unrepresentable;

      var moreFeatures = this.features.length > other.features.length
          ? this.features
          : other.features;
      var fewerFeatures = this.features.length > other.features.length
          ? other.features
          : this.features;

      // If one set of features is a superset of the other, use those features
      // because they're strictly narrower.
      if (fewerFeatures.every(moreFeatures.contains)) {
        modifier = ourModifier; // "not"
        type = ourType;
        features = moreFeatures;
      } else {
        // Otherwise, there's no way to represent the intersection.
        return MediaQueryMergeResult.unrepresentable;
      }
    } else if (ourType == null) {
      modifier = theirModifier;
      type = theirType;
      features = this.features.toList()..addAll(other.features);
    } else if (theirType == null) {
      modifier = ourModifier;
      type = ourType;
      features = this.features.toList()..addAll(other.features);
    } else if (ourType != theirType) {
      return MediaQueryMergeResult.empty;
    } else {
      modifier = ourModifier ?? theirModifier;
      type = ourType;
      features = this.features.toList()..addAll(other.features);
    }

    return new MediaQuerySuccessfulMergeResult._(new CssMediaQuery(
        type == ourType ? this.type : other.type,
        modifier: modifier == ourModifier ? this.modifier : other.modifier,
        features: features));
  }

  bool operator ==(other) =>
      other is CssMediaQuery &&
      other.modifier == modifier &&
      other.type == type &&
      listEquals(other.features, features);

  int get hashCode => modifier.hashCode ^ type.hashCode ^ listHash(features);

  String toString() {
    var buffer = new StringBuffer();
    if (modifier != null) buffer.write("$modifier ");
    if (type != null) {
      buffer.write(type);
      if (features.isNotEmpty) buffer.write(" and ");
    }
    buffer.write(features.join(" and "));
    return buffer.toString();
  }
}

/// The interface of possible return values of [CssMediaQuery.merge].
///
/// This is either the singleton values [empty] or [unrepresentable], or an
/// instance of [MediaQuerySuccessfulMergeResult].
abstract class MediaQueryMergeResult {
  /// A singleton value indicating that there are no contexts that match both
  /// input queries.
  static const empty = const _SingletonCssMediaQueryMergeResult("empty");

  /// A singleton value indicating that the contexts that match both input
  /// queries can't be represented by a Level 3 media query.
  static const unrepresentable =
      const _SingletonCssMediaQueryMergeResult("unrepresentable");
}

/// The subclass [MediaQueryMergeResult] that represents singleton enum values.
class _SingletonCssMediaQueryMergeResult implements MediaQueryMergeResult {
  /// The name of the result type.
  final String _name;

  const _SingletonCssMediaQueryMergeResult(this._name);

  String toString() => _name;
}

/// A successful result of [CssMediaQuery.merge].
class MediaQuerySuccessfulMergeResult implements MediaQueryMergeResult {
  /// The merged media query.
  final CssMediaQuery query;

  MediaQuerySuccessfulMergeResult._(this.query);
}
