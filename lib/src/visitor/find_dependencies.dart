// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';

import '../ast/sass.dart';
import 'recursive_statement.dart';

/// Returns [stylesheet]'s statically-declared dependencies.
///
/// {@category Dependencies}
DependencyReport findDependencies(Stylesheet stylesheet) =>
    _FindDependenciesVisitor().run(stylesheet);

/// A visitor that traverses a stylesheet and records all its dependencies on
/// other stylesheets.
class _FindDependenciesVisitor with RecursiveStatementVisitor {
  final _uses = <Uri>{};
  final _forwards = <Uri>{};
  final _metaLoadCss = <Uri>{};
  final _imports = <Uri>{};

  /// The namespaces under which `sass:meta` has been `@use`d in this stylesheet.
  ///
  /// If this contains `null`, it means `sass:meta` was loaded without a
  /// namespace.
  final _metaNamespaces = <String?>{};

  DependencyReport run(Stylesheet stylesheet) {
    visitStylesheet(stylesheet);
    return DependencyReport._(
        uses: UnmodifiableSetView(_uses),
        forwards: UnmodifiableSetView(_forwards),
        metaLoadCss: UnmodifiableSetView(_metaLoadCss),
        imports: UnmodifiableSetView(_imports));
  }

  // These can never contain imports.
  void visitEachRule(EachRule node) {}
  void visitForRule(ForRule node) {}
  void visitIfRule(IfRule node) {}
  void visitWhileRule(WhileRule node) {}
  void visitCallableDeclaration(CallableDeclaration node) {}
  void visitInterpolation(Interpolation interpolation) {}
  void visitSupportsCondition(SupportsCondition condition) {}

  void visitUseRule(UseRule node) {
    if (node.url.scheme != 'sass') {
      _uses.add(node.url);
    } else if (node.url.toString() == 'sass:meta') {
      _metaNamespaces.add(node.namespace);
    }
  }

  void visitForwardRule(ForwardRule node) {
    if (node.url.scheme != 'sass') _forwards.add(node.url);
  }

  void visitImportRule(ImportRule node) {
    for (var import in node.imports) {
      if (import is DynamicImport) _imports.add(import.url);
    }
  }

  void visitIncludeRule(IncludeRule node) {
    if (node.name != 'load-css') return;
    if (!_metaNamespaces.contains(node.namespace)) return;
    if (node.arguments.positional.isEmpty) return;
    var argument = node.arguments.positional.first;
    if (argument is! StringExpression) return;
    var url = argument.text.asPlain;
    try {
      if (url != null) _metaLoadCss.add(Uri.parse(url));
    } on FormatException {
      // Ignore invalid URLs.
    }
  }
}

/// A struct of different types of dependencies a Sass stylesheet can contain.
class DependencyReport {
  /// An unmodifiable set of all `@use`d URLs in the stylesheet (exluding
  /// built-in modules).
  final Set<Uri> uses;

  /// An unmodifiable set of all `@forward`ed URLs in the stylesheet (excluding
  /// built-in modules).
  final Set<Uri> forwards;

  /// An unmodifiable set of all URLs loaded by `meta.load-css()` calls with
  /// static string arguments outside of mixins.
  final Set<Uri> metaLoadCss;

  /// An unmodifiable set of all dynamically `@import`ed URLs in the
  /// stylesheet.
  final Set<Uri> imports;

  /// An unmodifiable set of all URLs in [uses], [forwards], and [metaLoadCss].
  Set<Uri> get modules => UnionSet({uses, forwards, metaLoadCss});

  /// An unmodifiable set of all URLs in [uses], [forwards], [metaLoadCss], and
  /// [imports].
  Set<Uri> get all => UnionSet({uses, forwards, metaLoadCss, imports});

  DependencyReport._(
      {required this.uses, required this.forwards, required this.metaLoadCss, required this.imports});
}
