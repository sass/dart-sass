// Copyright 2019 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'ast/node.dart';
import 'ast/sass.dart';
import 'configured_value.dart';
import 'util/limited_map_view.dart';
import 'util/unprefixed_map_view.dart';

/// A set of variables meant to configure a module by overriding its
/// `!default` declarations.
///
/// A configuration may be either *implicit*, meaning that it's either empty or
/// created by importing a file containing a `@forward` rule; or *explicit*,
/// meaning that it's created by passing a `with` clause to a `@use` rule.
/// Explicit configurations have spans associated with them and are represented
/// by the [ExplicitConfiguration] subclass.
class Configuration {
  /// A map from variable names (without `$`) to values.
  ///
  /// This map may not be modified directly. To remove a value from this
  /// configuration, use the [remove] method.
  Map<String, ConfiguredValue> get values => UnmodifiableMapView(_values);
  final Map<String, ConfiguredValue> _values;

  /// Creates an implicit configuration with the given [values].
  Configuration.implicit(this._values);

  /// The empty configuration, which indicates that the module has not been
  /// configured.
  ///
  /// Empty configurations are always considered implicit, since they are
  /// ignored if the module has already been loaded.
  const Configuration.empty() : _values = const {};

  bool get isEmpty => values.isEmpty;

  /// Removes a variable with [name] from this configuration, returning it.
  ///
  /// If no such variable exists in this configuration, returns null.
  ConfiguredValue? remove(String name) => isEmpty ? null : _values.remove(name);

  /// Creates a new configuration from this one based on a `@forward` rule.
  Configuration throughForward(ForwardRule forward) {
    if (isEmpty) return const Configuration.empty();
    var newValues = _values;

    // Only allow variables that are visible through the `@forward` to be
    // configured. These views support [Map.remove] so we can mark when a
    // configuration variable is used by removing it even when the underlying
    // map is wrapped.
    var prefix = forward.prefix;
    if (prefix != null) newValues = UnprefixedMapView(newValues, prefix);

    var shownVariables = forward.shownVariables;
    var hiddenVariables = forward.hiddenVariables;
    if (shownVariables != null) {
      newValues = LimitedMapView.safelist(newValues, shownVariables);
    } else if (hiddenVariables != null && hiddenVariables.isNotEmpty) {
      newValues = LimitedMapView.blocklist(newValues, hiddenVariables);
    }
    return _withValues(newValues);
  }

  /// Returns a copy of [this] with the given [values] map.
  Configuration _withValues(Map<String, ConfiguredValue> values) =>
      Configuration.implicit(values);

  String toString() =>
      "(" +
      values.entries
          .map((entry) => "\$${entry.key}: ${entry.value}")
          .join(", ") +
      ")";
}

/// A [Configuratoin] that was created with an explicit `with` clause of a
/// `@use` rule.
///
/// Both types of configuration pass through `@forward` rules, but explicit
/// configurations will cause an error if attempting to use them on a module
/// that has already been loaded, while implicit configurations will be
/// silently ignored in this case.
class ExplicitConfiguration extends Configuration {
  /// The node whose span indicates where the configuration was declared.
  final AstNode nodeWithSpan;

  ExplicitConfiguration(Map<String, ConfiguredValue> values, this.nodeWithSpan)
      : super.implicit(values);

  /// Returns a copy of [this] with the given [values] map.
  Configuration _withValues(Map<String, ConfiguredValue> values) =>
      ExplicitConfiguration(values, nodeWithSpan);
}
