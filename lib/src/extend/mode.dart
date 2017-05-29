// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/// Different modes in which extension can run.
class ExtendMode {
  /// Normal mode, used with the `@extend` rule.
  ///
  /// This preserves existing selectors and extends each target individually.
  static const normal = const ExtendMode._("normal");

  /// Replace mode, used by the `selector-replace()` function.
  ///
  /// This replaces existing selectors and requires every target to match to
  /// extend a given compound selector.
  static const replace = const ExtendMode._("replace");

  /// All-targets mode, used by the `selector-extend()` function.
  ///
  /// This preserves existing selectors but requires every target to match to
  /// extend a given compound selector.
  static const allTargets = const ExtendMode._("allTargets");

  /// The name of the mode.
  final String name;

  const ExtendMode._(this.name);

  String toString() => name;
}
