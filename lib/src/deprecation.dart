// Copyright 2022 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';
import 'package:pub_semver/pub_semver.dart';

import 'util/nullable.dart';

/// A deprecated feature in the language.
enum Deprecation {
  /// Deprecation for passing a string to `call` instead of `get-function`.
  callString('call-string',
      deprecatedIn: '0.0.0',
      description: 'Passing a string directly to meta.call().'),

  /// Deprecation for `@elseif`.
  elseif('elseif', deprecatedIn: '1.3.2', description: '@elseif.'),

  /// Deprecation for parsing `@-moz-document`.
  mozDocument('moz-document',
      deprecatedIn: '1.7.2', description: '@-moz-document.'),

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

  duplicateVariableFlags('duplicate-var-flags',
      deprecatedIn: '1.62.0',
      description:
          'Using !default or !global multiple times for one variable.'),

  colorFunctions('color-functions',
      deprecatedIn: '1.65.0',
      description: 'Using global Sass color functions.'),

  /// Deprecation for `@import` rules.
  import.future('import', description: '@import rules.'),

  /// Used for deprecations coming from user-authored code.
  userAuthored('user-authored', deprecatedIn: null);

  /// A unique ID for this deprecation in kebab case.
  ///
  /// This is used to refer to the deprecation on the command line.
  final String id;

  /// Underlying version string used by [deprecatedIn].
  ///
  /// This is necessary because [Version] doesn't have a constant constructor,
  /// so we can't use it directly as an enum property.
  final String? _deprecatedIn;

  /// The Dart Sass version this feature was first deprecated in.
  ///
  /// For deprecations that have existed in all versions of Dart Sass, this
  /// should be 0.0.0. For deprecations not related to a specific Sass version,
  /// this should be null.
  Version? get deprecatedIn => _deprecatedIn.andThen(Version.parse);

  /// A description of this deprecation that will be displayed in the CLI usage.
  ///
  /// If this is null, the given deprecation will not be listed.
  final String? description;

  /// Whether this deprecation will occur in the future.
  ///
  /// If this is true, `deprecatedIn` will be null, since we do not yet know
  /// what version of Dart Sass this deprecation will be live in.
  final bool isFuture;

  /// Constructs a regular deprecation.
  const Deprecation(this.id, {required String? deprecatedIn, this.description})
      : _deprecatedIn = deprecatedIn,
        isFuture = false;

  /// Constructs a future deprecation.
  const Deprecation.future(this.id, {this.description})
      : _deprecatedIn = null,
        isFuture = true;

  @override
  String toString() => id;

  /// Returns the deprecation with a given ID, or null if none exists.
  static Deprecation? fromId(String id) => Deprecation.values
      .firstWhereOrNull((deprecation) => deprecation.id == id);

  /// Returns the set of all deprecations done in or before [version].
  static Set<Deprecation> forVersion(Version version) {
    var range = VersionRange(max: version, includeMax: true);
    return {
      for (var deprecation in Deprecation.values)
        if (deprecation.deprecatedIn.andThen(range.allows) ?? false) deprecation
    };
  }
}
