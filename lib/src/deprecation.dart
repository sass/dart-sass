// Copyright 2022 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';
import 'package:pub_semver/pub_semver.dart';

/// Represents a deprecated feature in the language.
enum Deprecation {
  /// Deprecation for passing a string to `call` instead of `get-function`.
  callString('call-string',
      deprecatedIn: '0.0.0',
      description: 'Passing a string directly to meta.call().'),

  /// Deprecation for `@elseif`.
  elseIf('elseif', deprecatedIn: '1.3.2', description: '@elseif.'),

  /// Deprecation for parsing `@-moz-document`.
  mozDocument('moz-document', deprecatedIn: '1.7.2'),

  /// Deprecation for importers using relative canonical URLs.
  relativeCanonical('relative-canonical', deprecatedIn: '1.14.2'),

  /// Deprecation for declaring new variables with `!global`.
  newGlobal('new-global',
      deprecatedIn: '1.17.2',
      description: 'Declaring new variables with !global.'),

  /// Deprecation for certain functions in the color module matching the
  /// behavior of their global counterparts for compatiblity reasons.
  colorModuleCompat('color-module-compat',
      deprecatedIn: '1.23.0',
      description:
          'Using color module functions in place of plain CSS functions.'),

  /// Deprecation for treating `/` as division.
  slashDiv('slash-div',
      deprecatedIn: '1.33.0', description: '/ operator for division.'),

  /// Deprecation for leading, trailing, and repeated combinators.
  bogusCombinators('bogus-combinators',
      deprecatedIn: '1.54.0',
      description: 'Leading, trailing, and repeated combinators.'),

  /// Deprecation for ambiguous `+` and `-` operators.
  strictUnary('strict-unary',
      deprecatedIn: '1.55.0', description: 'Ambiguous + and - operators.'),

  /// Deprecation for passing invalid units to certain built-in functions.
  functionUnits('function-units',
      deprecatedIn: '1.56.0',
      description: 'Passing invalid units to built-in functions.'),

  /// Deprecation for `@import` rules.
  import('import', deprecatedIn: null, description: '@import rules.'),

  /// Used for deprecations of an unknown type.
  ///
  /// We set its deprecated-in version to 1000.0.0 so that it won't be made
  /// fatal by passing a Sass version to --fatal-deprecation.
  unknown('unknown', deprecatedIn: '1000.0.0');

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

  /// A description of this deprecation that will be displayed in the CLI usage.
  ///
  /// If this is null, the given deprecation will not be listed.
  final String? description;

  const Deprecation(this.id, {required this.deprecatedIn, this.description});

  @override
  String toString() => id;

  /// Returns the deprecation with a given ID, or null if none exists.
  static Deprecation? fromId(String id) => Deprecation.values
      .firstWhereOrNull((deprecation) => deprecation.id == id);

  /// Returns the set of all deprecations done in or before [version].
  static Set<Deprecation> forVersion(Version version) {
    return {
      for (var deprecation in Deprecation.values)
        if (deprecation.deprecatedIn != null &&
            Version.parse(deprecation.deprecatedIn!) <= version)
          deprecation
    };
  }
}
