// Copyright 2019 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'ast/sass.dart';
import 'configured_value.dart';
import 'util/limited_map_view.dart';
import 'util/unprefixed_map_view.dart';

/// A set of variables meant to configure a module by overriding its
/// `!default` declarations.
class Configuration {
  /// A map from variable names (without `$`) to values.
  ///
  /// This map may not be modified directly. To remove a value from this
  /// configuration, use the [remove] method.
  Map<String, ConfiguredValue> get values => UnmodifiableMapView(_values);
  final Map<String, ConfiguredValue> _values;

  /// Whether or not this configuration is implicit.
  ///
  /// Implicit configurations are created when a file containing a `@forward`
  /// rule is imported, while explicit configurations are created by the
  /// `with` clause of a `@use` rule.
  ///
  /// Both types of configuration pass through `@forward` rules, but explicit
  /// configurations will cause an error if attempting to use them on a module
  /// that has already been loaded, while implicit configurations will be
  /// silently ignored in this case.
  final bool isImplicit;

  Configuration(Map<String, ConfiguredValue> values, {this.isImplicit = false})
      : _values = values;

  /// The empty configuration, which indicates that the module has not been
  /// configured.
  ///
  /// Empty configurations are always considered implicit, since they are
  /// ignored if the module has already been loaded.
  const Configuration.empty()
      : _values = const {},
        isImplicit = true;

  bool get isEmpty => values.isEmpty;

  /// Removes a variable with [name] from this configuration, returning it.
  ///
  /// If no such variable exists in this configuration, returns null.
  ConfiguredValue remove(String name) => isEmpty ? null : _values.remove(name);

  /// Creates a new configuration from this one based on a `@forward` rule.
  Configuration throughForward(ForwardRule forward) {
    if (isEmpty) return const Configuration.empty();
    var newValues = _values;

    // Only allow variables that are visible through the `@forward` to be
    // configured. These views support [Map.remove] so we can mark when a
    // configuration variable is used by removing it even when the underlying
    // map is wrapped.
    if (forward.prefix != null) {
      newValues = UnprefixedMapView(newValues, forward.prefix);
    }
    if (forward.shownVariables != null) {
      newValues = LimitedMapView.safelist(newValues, forward.shownVariables);
    } else if (forward.hiddenVariables?.isNotEmpty ?? false) {
      newValues = LimitedMapView.blocklist(newValues, forward.hiddenVariables);
    }
    return Configuration(newValues, isImplicit: isImplicit);
  }
}
