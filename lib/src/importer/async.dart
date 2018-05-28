// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'result.dart';

/// An interface for importers that resolves URLs in `@import`s to the contents
/// of Sass files.
///
/// Importers should override [toString] to provide a human-readable description
/// of the importer. For example, the default filesystem importer returns its
/// load path.
///
/// This class should only be extended by importers that *need* to do
/// asynchronous work. It's only compatible with the asynchronous `compile()`
/// methods. If an importer can work synchronously, it should extend [Importer]
/// instead.
///
/// Subclasses should extend [AsyncImporter], not implement it.
abstract class AsyncImporter {
  /// If [url] is recognized by this importer, returns its canonical format.
  ///
  /// If Sass has already loaded a stylesheet with the returned canonical URL,
  /// it re-uses the existing parse tree. This means that importers **must
  /// ensure** that the same canonical URL always refers to the same stylesheet,
  /// *even across different importers*.
  ///
  /// This may return `null` if [url] isn't recognized by this importer.
  ///
  /// If this importer's URL format supports file extensions, it should
  /// canonicalize them the same way as the default filesystem importer:
  ///
  /// * If the [url] ends in `.sass` or `.scss`, the importer should look for
  ///   a stylesheet with that exact URL and return `null` if it's not found.
  ///
  /// * Otherwise, the importer should look for a stylesheet by filling in
  ///   extensions and partial prefixes. The extension `.sass` before `.scss`,
  ///   and using the partial prefix before without the prefix:
  ///   * `"_$url.sass"`
  ///   * `"$url.sass"`
  ///   * `"_$url.scss"`
  ///   * `"$url.scss"`
  ///
  /// * Finally, the importer should check for a directory default index.
  ///   * `"$url/_index.sass"`
  ///   * `"$url/index.sass"`
  ///   * `"$url/_index.scss"`
  ///   * `"$url/index.scss"`
  ///
  /// If none are found, it should return `null`.
  ///
  /// Sass assumes that calling [canonicalize] multiple times with the same URL
  /// will return the same result.
  FutureOr<Uri> canonicalize(Uri url);

  /// Loads the Sass text for the given [url], or returns `null` if
  /// this importer can't find the stylesheet it refers to.
  ///
  /// The [url] comes from a call to [canonicalize] for this importer.
  ///
  /// When Sass encounters an `@import` rule in a stylesheet, it first calls
  /// [canonicalize] and [load] on the importer that first loaded that
  /// stylesheet with the imported URL resolved relative to the stylesheet's
  /// original URL. If either of those returns `null`, it then calls
  /// [canonicalize] and [load] on each importer in order with the URL as it
  /// appears in the `@import` rule.
  ///
  /// If the importer finds a stylesheet at [url] but it fails to load for some
  /// reason, or if [url] is uniquely associated with this importer but doesn't
  /// refer to a real stylesheet, the importer may throw an exception that will
  /// be wrapped by Sass. If the exception object has a `message` property, it
  /// will be used as the wrapped exception's message; otherwise, the exception
  /// object's `toString()` will be used. This means it's safe for importers to
  /// throw plain strings.
  FutureOr<ImporterResult> load(Uri url);

  /// Returns the time that the Sass file at [url] was last modified.
  ///
  /// The [url] comes from a call to [canonicalize] for this importer.
  ///
  /// By default, this returns the current time, indicating that [url] should be
  /// reloaded on every compilation. If implementations override this to provide
  /// a more accurate time, Sass will be better able to avoid recompiling it
  /// unnecessarily.
  ///
  /// If this throws an exception, the exception is ignored and the current time
  /// is used as the modification time.
  FutureOr<DateTime> modificationTime(Uri url) => new DateTime.now();
}
