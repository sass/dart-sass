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
  CssMediaQuery merge(CssMediaQuery other) {
    var ourModifier = this.modifier?.toLowerCase();
    var ourType = this.type?.toLowerCase();
    var theirModifier = other.modifier?.toLowerCase();
    var theirType = other.type?.toLowerCase();

    if (ourType == null && theirType == null) {
      return new CssMediaQuery.condition(
          features.toList()..addAll(other.features));
    }

    String modifier;
    String type;
    if ((ourModifier == 'not') != (theirModifier == 'not')) {
      if (ourType == theirType) return null;

      if (ourModifier == 'not') {
        // The "not" would apply to the other query's features, which is not
        // what we want.
        if (other.features.isNotEmpty) return null;
        modifier = theirModifier;
        type = theirType;
      } else {
        if (this.features.isNotEmpty) return null;
        modifier = ourModifier;
        type = ourType;
      }
    } else if (ourModifier == 'not') {
      assert(theirModifier == 'not');
      // CSS has no way of representing "neither screen nor print".
      if (ourType == theirType) return null;
      modifier = ourModifier; // "not"
      type = ourType;
    } else if (ourType == null) {
      modifier = theirModifier;
      type = theirType;
    } else if (theirType == null) {
      modifier = ourModifier;
      type = ourType;
    } else if (ourType != theirType) {
      return null;
    } else {
      modifier = ourModifier ?? theirModifier;
      type = ourType;
    }

    return new CssMediaQuery(type == ourType ? this.type : other.type,
        modifier: modifier == ourModifier ? this.modifier : other.modifier,
        features: features.toList()..addAll(other.features));
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
