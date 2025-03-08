// Copyright 2024 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:cli_pkg/js.dart';
import 'package:collection/collection.dart';
import 'package:pub_semver/pub_semver.dart';

import 'util/nullable.dart';

/// A deprecated feature in the language.
enum Deprecation {
  // START AUTOGENERATED CODE
  //
  // DO NOT EDIT. This section was generated from the language repo.
  // See tool/grind/generate_deprecations.dart for details.
  //
  // Checksum: f34f224d924705c05c56bfc57a398706597f6c64

  /// Deprecation for passing a string directly to meta.call().
  callString('call-string',
      deprecatedIn: '0.0.0',
      description: 'Passing a string directly to meta.call().'),

  /// Deprecation for @elseif.
  elseif('elseif', deprecatedIn: '1.3.2', description: '@elseif.'),

  /// Deprecation for @-moz-document.
  mozDocument('moz-document',
      deprecatedIn: '1.7.2',
      obsoleteIn: '2.0.0',
      description: '@-moz-document.'),

  /// Deprecation for imports using relative canonical URLs.
  relativeCanonical('relative-canonical',
      deprecatedIn: '1.14.2',
      description: 'Imports using relative canonical URLs.'),

  /// Deprecation for declaring new variables with !global.
  newGlobal('new-global',
      deprecatedIn: '1.17.2',
      description: 'Declaring new variables with !global.'),

  /// Deprecation for using color module functions in place of plain CSS functions.
  colorModuleCompat('color-module-compat',
      deprecatedIn: '1.23.0',
      description:
          'Using color module functions in place of plain CSS functions.'),

  /// Deprecation for / operator for division.
  slashDiv('slash-div',
      deprecatedIn: '1.33.0', description: '/ operator for division.'),

  /// Deprecation for leading, trailing, and repeated combinators.
  bogusCombinators('bogus-combinators',
      deprecatedIn: '1.54.0',
      obsoleteIn: '2.0.0',
      description: 'Leading, trailing, and repeated combinators.'),

  /// Deprecation for ambiguous + and - operators.
  strictUnary('strict-unary',
      deprecatedIn: '1.55.0', description: 'Ambiguous + and - operators.'),

  /// Deprecation for passing invalid units to built-in functions.
  functionUnits('function-units',
      deprecatedIn: '1.56.0',
      description: 'Passing invalid units to built-in functions.'),

  /// Deprecation for using !default or !global multiple times for one variable.
  duplicateVarFlags('duplicate-var-flags',
      deprecatedIn: '1.62.0',
      description:
          'Using !default or !global multiple times for one variable.'),

  /// Deprecation for passing null as alpha in the ${isJS ? 'JS': 'Dart'} API.
  nullAlpha('null-alpha',
      deprecatedIn: '1.62.3',
      description: 'Passing null as alpha in the ${isJS ? 'JS' : 'Dart'} API.'),

  /// Deprecation for passing percentages to the Sass abs() function.
  absPercent('abs-percent',
      deprecatedIn: '1.65.0',
      description: 'Passing percentages to the Sass abs() function.'),

  /// Deprecation for using the current working directory as an implicit load path.
  fsImporterCwd('fs-importer-cwd',
      deprecatedIn: '1.73.0',
      description:
          'Using the current working directory as an implicit load path.'),

  /// Deprecation for function and mixin names beginning with --.
  cssFunctionMixin('css-function-mixin',
      deprecatedIn: '1.76.0',
      description: 'Function and mixin names beginning with --.'),

  /// Deprecation for declarations after or between nested rules.
  mixedDecls('mixed-decls',
      deprecatedIn: '1.77.7',
      description: 'Declarations after or between nested rules.'),

  /// Deprecation for meta.feature-exists
  featureExists('feature-exists',
      deprecatedIn: '1.78.0', description: 'meta.feature-exists'),

  /// Deprecation for certain uses of built-in sass:color functions.
  color4Api('color-4-api',
      deprecatedIn: '1.79.0',
      description: 'Certain uses of built-in sass:color functions.'),

  /// Deprecation for using global color functions instead of sass:color.
  colorFunctions('color-functions',
      deprecatedIn: '1.79.0',
      description: 'Using global color functions instead of sass:color.'),

  /// Deprecation for legacy JS API.
  legacyJsApi('legacy-js-api',
      deprecatedIn: '1.79.0', description: 'Legacy JS API.'),

  /// Deprecation for @import rules.
  import('import', deprecatedIn: '1.80.0', description: '@import rules.'),

  /// Deprecation for global built-in functions that are available in sass: modules.
  globalBuiltin('global-builtin',
      deprecatedIn: '1.80.0',
      description:
          'Global built-in functions that are available in sass: modules.'),

  // END AUTOGENERATED CODE

  /// Used for deprecations coming from user-authored code.
  userAuthored('user-authored', deprecatedIn: null),

  @Deprecated('This deprecation name was never actually used.')
  calcInterp('calc-interp', deprecatedIn: null);

  @Deprecated('Use duplicateVarFlags instead.')
  static const duplicateVariableFlags = duplicateVarFlags;

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

  /// Underlying version string used by [obsoleteIn].
  ///
  /// This is necessary because [Version] doesn't have a constant constructor,
  /// so we can't use it directly as an enum property.
  final String? _obsoleteIn;

  /// The Dart Sass version this feature was fully removed in, making the
  /// deprecation obsolete.
  ///
  /// For deprecations that are not yet obsolete, this should be null.
  Version? get obsoleteIn => _obsoleteIn?.andThen(Version.parse);

  /// Constructs a regular deprecation.
  const Deprecation(this.id,
      {required String? deprecatedIn, this.description, String? obsoleteIn})
      : _deprecatedIn = deprecatedIn,
        _obsoleteIn = obsoleteIn,
        isFuture = false;

  /// Constructs a future deprecation.
  // ignore: unused_element, unused_element_parameter
  const Deprecation.future(this.id, {this.description})
      : _deprecatedIn = null,
        _obsoleteIn = null,
        isFuture = true;

  @override
  String toString() => id;

  /// Returns the deprecation with a given ID, or null if none exists.
  static Deprecation? fromId(String id) => Deprecation.values.firstWhereOrNull(
        (deprecation) => deprecation.id == id,
      );

  /// Returns the set of all deprecations done in or before [version].
  static Set<Deprecation> forVersion(Version version) {
    var range = VersionRange(max: version, includeMax: true);
    return {
      for (var deprecation in Deprecation.values)
        if (deprecation.deprecatedIn.andThen(range.allows) ?? false)
          deprecation,
    };
  }
}
