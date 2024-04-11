// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:path/path.dart' as p;

import '../io.dart';
import './canonicalize_context.dart';

/// Whether the Sass compiler is currently evaluating an `@import` rule.
///
/// When evaluating `@import` rules, URLs should canonicalize to an import-only
/// file if one exists for the URL being canonicalized. Otherwise,
/// canonicalization should be identical for `@import` and `@use` rules. It's
/// admittedly hacky to set this globally, but `@import` will eventually be
/// removed, at which point we can delete this and have one consistent behavior.
bool get fromImport =>
    ((Zone.current[#_canonicalizeContext] as CanonicalizeContext?)
            ?.fromImport ??
        false);

/// The CanonicalizeContext of the current load.
CanonicalizeContext get canonicalizeContext =>
    switch (Zone.current[#_canonicalizeContext]) {
      null => throw StateError(
          "canonicalizeContext may only be accessed within a call to canonicalize()."),
      CanonicalizeContext context => context,
      var value => throw StateError(
          "Unexpected Zone.current[#_canonicalizeContext] value $value.")
    };

/// Runs [callback] in a context where [fromImport] returns `true` and
/// [resolveImportPath] uses `@import` semantics rather than `@use` semantics.
T inImportRule<T>(T callback()) =>
    switch (Zone.current[#_canonicalizeContext]) {
      null => runZoned(callback,
          zoneValues: {#_canonicalizeContext: CanonicalizeContext(null, true)}),
      CanonicalizeContext context => context.withFromImport(true, callback),
      var value => throw StateError(
          "Unexpected Zone.current[#_canonicalizeContext] value $value.")
    };

/// Runs [callback] in the given context.
T withCanonicalizeContext<T>(CanonicalizeContext? context, T callback()) =>
    runZoned(callback, zoneValues: {#_canonicalizeContext: context});

/// Resolves an imported path using the same logic as the filesystem importer.
///
/// This tries to fill in extensions and partial prefixes and check for a
/// directory default. If no file can be found, it returns `null`.
String? resolveImportPath(String path) {
  var extension = p.extension(path);
  if (extension == '.sass' || extension == '.scss' || extension == '.css') {
    return _ifInImport<String?>(() => _exactlyOne(
            _tryPath('${p.withoutExtension(path)}.import$extension'))) ??
        _exactlyOne(_tryPath(path));
  }

  return _ifInImport<String?>(
          () => _exactlyOne(_tryPathWithExtensions('$path.import'))) ??
      _exactlyOne(_tryPathWithExtensions(path)) ??
      _tryPathAsDirectory(path);
}

/// Like [_tryPath], but checks `.sass`, `.scss`, and `.css` extensions.
List<String> _tryPathWithExtensions(String path) {
  var result = _tryPath(path + '.sass')..addAll(_tryPath(path + '.scss'));
  return result.isNotEmpty ? result : _tryPath(path + '.css');
}

/// Returns the [path] and/or the partial with the same name, if either or both
/// exists.
///
/// If neither exists, returns an empty list.
List<String> _tryPath(String path) {
  var partial = p.join(p.dirname(path), "_${p.basename(path)}");
  return [if (fileExists(partial)) partial, if (fileExists(path)) path];
}

/// Returns the resolved index file for [path] if [path] is a directory and the
/// index file exists.
///
/// Otherwise, returns `null`.
String? _tryPathAsDirectory(String path) {
  if (!dirExists(path)) return null;

  return _ifInImport<String?>(() =>
          _exactlyOne(_tryPathWithExtensions(p.join(path, 'index.import')))) ??
      _exactlyOne(_tryPathWithExtensions(p.join(path, 'index')));
}

/// If [paths] contains exactly one path, returns that path.
///
/// If it contains no paths, returns `null`. If it contains more than one,
/// throws an exception.
String? _exactlyOne(List<String> paths) => switch (paths) {
      [] => null,
      [var path] => path,
      _ => throw "It's not clear which file to import. Found:\n" +
          paths.map((path) => "  " + p.prettyUri(p.toUri(path))).join("\n")
    };

/// If [fromImport] is `true`, invokes callback and returns the result.
///
/// Otherwise, returns `null`.
T? _ifInImport<T>(T callback()) => fromImport ? callback() : null;

/// A regular expression matching valid URL schemes.
final _urlSchemeRegExp = RegExp(r"^[a-z0-9+.-]+$");

/// Returns whether [scheme] is a valid URL scheme.
bool isValidUrlScheme(String scheme) => _urlSchemeRegExp.hasMatch(scheme);
