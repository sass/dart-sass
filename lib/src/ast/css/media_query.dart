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
  final String? modifier;

  /// The media type, for example "screen" or "print".
  ///
  /// This may be `null`. If so, [conditions] will not be empty.
  final String? type;

  /// Whether [conditions] is a conjunction or a disjunction.
  ///
  /// In other words, if this is `true` this query matches when _all_
  /// [conditions] are met, and if it's `false` this query matches when _any_
  /// condition in [conditions] is met.
  ///
  /// If this is `false`, [modifier] and [type] will both be `null`.
  final bool conjunction;

  /// Media conditions, including parentheses.
  ///
  /// This is anything that can appear in the [`<media-in-parens>`] production.
  ///
  /// [`<media-in-parens>`]: https://drafts.csswg.org/mediaqueries-4/#typedef-media-in-parens
  final List<String> conditions;

  /// Whether this media query matches all media types.
  bool get matchesAllTypes => type == null || equalsIgnoreCase(type, 'all');

  /// Parses a media query from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  static List<CssMediaQuery> parseList(String contents,
          {Object? url, Logger? logger}) =>
      MediaQueryParser(contents, url: url, logger: logger).parse();

  /// Creates a media query specifies a type and, optionally, conditions.
  ///
  /// This always sets [conjunction] to `true`.
  CssMediaQuery.type(this.type, {this.modifier, Iterable<String>? conditions})
      : conjunction = true,
        conditions =
            conditions == null ? const [] : List.unmodifiable(conditions);

  /// Creates a media query that matches [conditions] according to
  /// [conjunction].
  ///
  /// The [conjunction] argument may not be null if [conditions] is longer than
  /// a single element.
  CssMediaQuery.condition(Iterable<String> conditions, {bool? conjunction})
      : modifier = null,
        type = null,
        conjunction = conjunction ?? true,
        conditions = List.unmodifiable(conditions) {
    if (this.conditions.length > 1 && conjunction == null) {
      throw ArgumentError(
          "If conditions is longer than one element, conjunction may not be "
          "null.");
    }
  }

  /// Merges this with [other] to return a query that matches the intersection
  /// of both inputs.
  MediaQueryMergeResult merge(CssMediaQuery other) {
    if (!conjunction || !other.conjunction) {
      return MediaQueryMergeResult.unrepresentable;
    }

    var ourModifier = this.modifier?.toLowerCase();
    var ourType = this.type?.toLowerCase();
    var theirModifier = other.modifier?.toLowerCase();
    var theirType = other.type?.toLowerCase();

    if (ourType == null && theirType == null) {
      return MediaQuerySuccessfulMergeResult._(CssMediaQuery.condition(
          [...this.conditions, ...other.conditions],
          conjunction: true));
    }

    String? modifier;
    String? type;
    List<String> conditions;
    if ((ourModifier == 'not') != (theirModifier == 'not')) {
      if (ourType == theirType) {
        var negativeConditions =
            ourModifier == 'not' ? this.conditions : other.conditions;
        var positiveConditions =
            ourModifier == 'not' ? other.conditions : this.conditions;

        // If the negative conditions are a subset of the positive conditions, the
        // query is empty. For example, `not screen and (color)` has no
        // intersection with `screen and (color) and (grid)`.
        //
        // However, `not screen and (color)` *does* intersect with `screen and
        // (grid)`, because it means `not (screen and (color))` and so it allows
        // a screen with no color but with a grid.
        if (negativeConditions.every(positiveConditions.contains)) {
          return MediaQueryMergeResult.empty;
        } else {
          return MediaQueryMergeResult.unrepresentable;
        }
      } else if (matchesAllTypes || other.matchesAllTypes) {
        return MediaQueryMergeResult.unrepresentable;
      }

      if (ourModifier == 'not') {
        modifier = theirModifier;
        type = theirType;
        conditions = other.conditions;
      } else {
        modifier = ourModifier;
        type = ourType;
        conditions = this.conditions;
      }
    } else if (ourModifier == 'not') {
      assert(theirModifier == 'not');
      // CSS has no way of representing "neither screen nor print".
      if (ourType != theirType) return MediaQueryMergeResult.unrepresentable;

      var moreConditions = this.conditions.length > other.conditions.length
          ? this.conditions
          : other.conditions;
      var fewerConditions = this.conditions.length > other.conditions.length
          ? other.conditions
          : this.conditions;

      // If one set of conditions is a superset of the other, use those conditions
      // because they're strictly narrower.
      if (fewerConditions.every(moreConditions.contains)) {
        modifier = ourModifier; // "not"
        type = ourType;
        conditions = moreConditions;
      } else {
        // Otherwise, there's no way to represent the intersection.
        return MediaQueryMergeResult.unrepresentable;
      }
    } else if (matchesAllTypes) {
      modifier = theirModifier;
      // Omit the type if either input query did, since that indicates that they
      // aren't targeting a browser that requires "all and".
      type = (other.matchesAllTypes && ourType == null) ? null : theirType;
      conditions = [...this.conditions, ...other.conditions];
    } else if (other.matchesAllTypes) {
      modifier = ourModifier;
      type = ourType;
      conditions = [...this.conditions, ...other.conditions];
    } else if (ourType != theirType) {
      return MediaQueryMergeResult.empty;
    } else {
      modifier = ourModifier ?? theirModifier;
      type = ourType;
      conditions = [...this.conditions, ...other.conditions];
    }

    return MediaQuerySuccessfulMergeResult._(CssMediaQuery.type(
        type == ourType ? this.type : other.type,
        modifier: modifier == ourModifier ? this.modifier : other.modifier,
        conditions: conditions));
  }

  bool operator ==(Object other) =>
      other is CssMediaQuery &&
      other.modifier == modifier &&
      other.type == type &&
      listEquals(other.conditions, conditions);

  int get hashCode => modifier.hashCode ^ type.hashCode ^ listHash(conditions);

  String toString() {
    var buffer = StringBuffer();
    if (modifier != null) buffer.write("$modifier ");
    if (type != null) {
      buffer.write(type);
      if (conditions.isNotEmpty) buffer.write(" and ");
    }
    buffer.write(conditions.join(conjunction ? " and " : " or "));
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
  static const empty = _SingletonCssMediaQueryMergeResult("empty");

  /// A singleton value indicating that the contexts that match both input
  /// queries can't be represented by a Level 3 media query.
  static const unrepresentable =
      _SingletonCssMediaQueryMergeResult("unrepresentable");
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
