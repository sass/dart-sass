// Copyright 2019 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'ast/node.dart';
import 'ast/sass.dart';
import 'util/limited_map_view.dart';
import 'util/unprefixed_map_view.dart';
import 'value.dart';

/// A set of variables meant to configure a module by overriding its
/// `!default` declarations.
///
/// There are two types of configuration: an explicit one that's created by
/// the `with` clause of a `@use` rule and an implicit one that's created any
/// time a file containing a `@forward` rule is imported.
///
/// Both types of configuration pass through `@forward` rules, but explicit
/// configurations will cause an error if attempting to use them on a module
/// that has already been loaded, while implicit configurations will be silently
/// ignored in this case.
class Configuration {
  /// A map from variable names (without `$`) to values.
  ///
  /// When this is empty, it may be unmodifiable, so [Map.remove] should not be
  /// called on this.
  final Map<String, ConfiguredValue> values;

  /// Whether or not this configuration is implicit.
  final bool isImplicit;

  Configuration(this.values, {this.isImplicit = false});

  /// The empty configuration, which indicates that the module has not been
  /// configured.
  const Configuration.empty()
      : values = const {},
        isImplicit = false;

  bool get isEmpty => values.isEmpty;
  bool get isNotEmpty => values.isNotEmpty;

  /// Creates a new configuration from this one based on a `@forward` rule.
  Configuration throughForward(ForwardRule forward) {
    if (isEmpty) return const Configuration.empty();
    var newValues = values;

    // Only allow variables that are visible through the `@forward` to be
    // configured. These views support [Map.remove] so we can mark when a
    // configuration variable is used by removing it even when the underlying
    // map is wrapped.
    if (forward.prefix != null) {
      newValues = UnprefixedMapView(newValues, forward.prefix);
    }
    if (forward.shownVariables != null) {
      newValues = LimitedMapView.whitelist(newValues, forward.shownVariables);
    } else if (forward.hiddenVariables?.isNotEmpty ?? false) {
      newValues = LimitedMapView.blacklist(newValues, forward.hiddenVariables);
    }
    return Configuration(newValues, isImplicit: isImplicit);
  }

  /// Creates a copy of this configuration.
  Configuration clone() => isEmpty
      ? const Configuration.empty()
      : Configuration({...values}, isImplicit: isImplicit);
}

/// A variable value that's been configured using `@use ... with`.
class ConfiguredValue {
  /// The value of the variable.
  final Value value;

  /// The span where the variable's configuration was written.
  final FileSpan configurationSpan;

  /// The [AstNode] where the variable's value originated.
  ///
  /// This is used to generate source maps.
  final AstNode assignmentNode;

  ConfiguredValue(this.value, this.configurationSpan, [this.assignmentNode]);
}
