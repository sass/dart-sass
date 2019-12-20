// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../configured_variable.dart';
import '../expression/string.dart';
import '../statement.dart';

/// A `@forward` rule.
class ForwardRule implements Statement {
  /// The URI of the module to forward.
  ///
  /// If this is relative, it's relative to the containing file.
  final Uri url;

  /// The set of mixin and function names that may be accessed from the
  /// forwarded module.
  ///
  /// If this is empty, no mixins or functions may be accessed. If it's `null`,
  /// it imposes no restrictions on which mixins and function may be accessed.
  ///
  /// If this is non-`null`, [hiddenMixinsAndFunctions] and [hiddenVariables]
  /// are guaranteed to both be `null` and [shownVariables] is guaranteed to be
  /// non-`null`.
  final Set<String> shownMixinsAndFunctions;

  /// The set of variable names (without `$`) that may be accessed from the
  /// forwarded module.
  ///
  /// If this is empty, no variables may be accessed. If it's `null`, it imposes
  /// no restrictions on which variables may be accessed.
  ///
  /// If this is non-`null`, [hiddenMixinsAndFunctions] and [hiddenVariables]
  /// are guaranteed to both be `null` and [shownMixinsAndFunctions] is
  /// guaranteed to be non-`null`.
  final Set<String> shownVariables;

  /// The set of mixin and function names that may not be accessed from the
  /// forwarded module.
  ///
  /// If this is empty, any mixins or functions may be accessed. If it's `null`,
  /// it imposes no restrictions on which mixins or functions may be accessed.
  ///
  /// If this is non-`null`, [shownMixinsAndFunctions] and [shownVariables] are
  /// guaranteed to both be `null` and [hiddenVariables] is guaranteed to be
  /// non-`null`.
  final Set<String> hiddenMixinsAndFunctions;

  /// The set of variable names (without `$`) that may be accessed from the
  /// forwarded module.
  ///
  /// If this is empty, any variables may be accessed. If it's `null`, it
  /// imposes no restrictions on which variables may be accessed.
  ///
  /// If this is non-`null`, [shownMixinsAndFunctions] and [shownVariables] are
  /// guaranteed to both be `null` and [hiddenMixinsAndFunctions] is guaranteed
  /// to be non-`null`.
  final Set<String> hiddenVariables;

  /// The prefix to add to the beginning of the names of members of the used
  /// module, or `null` if member names are used as-is.
  final String prefix;

  /// A list of variable assignments used to configure the loaded modules.
  final List<ConfiguredVariable> configuration;

  final FileSpan span;

  /// Creates a `@forward` rule that allows all members to be accessed.
  ForwardRule(this.url, this.span,
      {this.prefix, Iterable<ConfiguredVariable> configuration})
      : shownMixinsAndFunctions = null,
        shownVariables = null,
        hiddenMixinsAndFunctions = null,
        hiddenVariables = null,
        configuration =
            configuration == null ? const [] : List.unmodifiable(configuration);

  /// Creates a `@forward` rule that allows only members included in
  /// [shownMixinsAndFunctions] and [shownVariables] to be accessed.
  ForwardRule.show(this.url, Iterable<String> shownMixinsAndFunctions,
      Iterable<String> shownVariables, this.span,
      {this.prefix, Iterable<ConfiguredVariable> configuration})
      : shownMixinsAndFunctions =
            UnmodifiableSetView(Set.of(shownMixinsAndFunctions)),
        shownVariables = UnmodifiableSetView(Set.of(shownVariables)),
        hiddenMixinsAndFunctions = null,
        hiddenVariables = null,
        configuration =
            configuration == null ? const [] : List.unmodifiable(configuration);

  /// Creates a `@forward` rule that allows only members not included in
  /// [hiddenMixinsAndFunctions] and [hiddenVariables] to be accessed.
  ForwardRule.hide(this.url, Iterable<String> hiddenMixinsAndFunctions,
      Iterable<String> hiddenVariables, this.span,
      {this.prefix, Iterable<ConfiguredVariable> configuration})
      : shownMixinsAndFunctions = null,
        shownVariables = null,
        hiddenMixinsAndFunctions =
            UnmodifiableSetView(Set.of(hiddenMixinsAndFunctions)),
        hiddenVariables = UnmodifiableSetView(Set.of(hiddenVariables)),
        configuration =
            configuration == null ? const [] : List.unmodifiable(configuration);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitForwardRule(this);

  String toString() {
    var buffer =
        StringBuffer("@forward ${StringExpression.quoteText(url.toString())}");

    if (shownMixinsAndFunctions != null) {
      buffer
        ..write(" show ")
        ..write(_memberList(shownMixinsAndFunctions, shownVariables));
    } else if (hiddenMixinsAndFunctions != null) {
      buffer
        ..write(" hide ")
        ..write(_memberList(hiddenMixinsAndFunctions, hiddenVariables));
    }

    if (prefix != null) buffer.write(" as $prefix*");

    if (configuration.isNotEmpty) {
      buffer.write(" with (${configuration.join(", ")})");
    }

    buffer.write(";");
    return buffer.toString();
  }

  /// Returns a combined list of names of the given members.
  String _memberList(
          Iterable<String> mixinsAndFunctions, Iterable<String> variables) =>
      shownMixinsAndFunctions
          .followedBy(shownVariables.map((name) => "\$$name"))
          .join(", ");
}
