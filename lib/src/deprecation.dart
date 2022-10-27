import 'package:pub_semver/pub_semver.dart';

/// Represents a deprecated feature in the language.
enum Deprecation {
  /// Deprecation for passing a string to `call` instead of `get-function`.
  callString('call-string', deprecatedIn: '0.0.0'),

  /// Deprecation for passing a number to a color function.
  colorNumber('color-number', deprecatedIn: '0.0.0'),

  /// Deprecation for using `color.alpha()` in a Microsoft filter.
  microsoftAlpha('microsoft-alpha', deprecatedIn: '0.0.0'),

  /// Deprecation for `@elseif`.
  elseIf('else-if', deprecatedIn: '1.3.2'),

  /// Deprecation for parsing `@-moz-document`.
  mozDocument('moz-document', deprecatedIn: '1.7.2'),

  /// Deprecation for importers using relative canonical URLs.
  relativeCanonical('relative-canonical', deprecatedIn: '1.14.2'),

  /// Deprecation for declaring new variables with `!global`.
  newGlobal('new-global', deprecatedIn: '1.17.2'),

  /// Deprecation for passing invalid units to certain color functions.
  colorUnits('color-units', deprecatedIn: '1.32.0'),

  /// Deprecation for treating `/` as division.
  slashDiv('slash-div', deprecatedIn: '1.33.0'),

  /// Deprecation for leading, trailing, and repeated combinators.
  bogusCombinators('bogus-combinators', deprecatedIn: '1.54.0'),

  /// Deprecation for SassScript boolean operators in `@media` queries.
  mediaLogic('media-logic', deprecatedIn: '1.54.0'),

  /// Deprecation for passing numbers with units to `math.random()`.
  randomWithUnits('random-with-units', deprecatedIn: '1.54.5'),

  /// Deprecation for ambiguous `+` and `-` operators.
  strictUnary('strict-unary', deprecatedIn: '1.55.0'),

  /// Deprecation for `@import` rules.
  import('import', deprecatedIn: null),

  /// Used for deprecations of an unknown type.
  unknown('unknown', deprecatedIn: null);

  /// A unique ID for this deprecation in kebab case.
  ///
  /// This is used to refer to the deprecation on the command line.
  final String id;

  /// The Dart Sass version this feature was first deprecated in.
  ///
  /// For deprecations that have existed in all versions of Dart Sass, this
  /// should be 0.0.0. For deprecations that are not yet active, this should be
  /// null.
  final String? deprecatedIn;
  const Deprecation(this.id, {required this.deprecatedIn});

  @override
  String toString() => id;

  /// Returns the set of all deprecations done in or before [version].
  static Set<Deprecation> forVersion(String version) {
    var maxVersion = Version.parse(version);
    return {
      for (var deprecation in Deprecation.values)
        if (deprecation.deprecatedIn != null &&
            Version.parse(deprecation.deprecatedIn!) <= maxVersion)
          deprecation
    };
  }
}
