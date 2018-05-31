// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:args/args.dart';
import 'package:meta/meta.dart';

import '../../sass.dart';
import '../io.dart';
import '../util/path.dart';

/// The parsed and processed command-line options for the Sass executable.
///
/// The constructor and any members may throw [UsageException]s indicating that
/// invalid arguments were passed.
class ExecutableOptions {
  /// The bar character to use in help separators.
  static final _separatorBar = isWindows ? '=' : '━';

  /// The total length of help separators, including text.
  static final _separatorLength = 40;

  /// The parser that defines the arguments the executable allows.
  static final ArgParser _parser = () {
    var parser = new ArgParser(allowTrailingOptions: true)

      // This is used for compatibility with sass-spec, even though we don't
      // support setting the precision.
      ..addOption('precision', hide: true)

      // This is used when testing to ensure that the asynchronous evaluator path
      // works the same as the synchronous one.
      ..addFlag('async', hide: true);

    parser
      ..addSeparator(_separator('Input and Output'))
      ..addFlag('stdin', help: 'Read the stylesheet from stdin.')
      ..addFlag('indented',
          help: 'Use the indented syntax for input from stdin.')
      ..addMultiOption('load-path',
          abbr: 'I',
          valueHelp: 'PATH',
          help: 'A path to use when resolving imports.\n'
              'May be passed multiple times.',
          splitCommas: false)
      ..addOption('style',
          abbr: 's',
          valueHelp: 'NAME',
          help: 'Output style.',
          allowed: ['expanded', 'compressed'],
          defaultsTo: 'expanded')
      ..addFlag('update',
          help: 'Only compile out-of-date stylesheets.', negatable: false);

    parser
      ..addSeparator(_separator('Source Maps'))
      ..addFlag('source-map',
          help: 'Whether to generate source maps.', defaultsTo: true)
      ..addOption('source-map-urls',
          defaultsTo: 'relative',
          help: 'How to link from source maps to source files.',
          allowed: ['relative', 'absolute'])
      ..addFlag('embed-sources',
          help: 'Embed source file contents in source maps.', defaultsTo: false)
      ..addFlag('embed-source-map',
          help: 'Embed source map contents in CSS.', defaultsTo: false);

    parser
      ..addSeparator(_separator('Other'))
      ..addFlag('interactive',
          abbr: 'i',
          help: 'Run an interactive SassScript shell.',
          negatable: false)
      ..addFlag('color', abbr: 'c', help: 'Whether to emit terminal colors.')
      ..addFlag('quiet', abbr: 'q', help: "Don't print warnings.")
      ..addFlag('trace', help: 'Print full Dart stack traces for exceptions.')
      ..addFlag('help',
          abbr: 'h', help: 'Print this usage information.', negatable: false)
      ..addFlag('version',
          help: 'Print the version of Dart Sass.', negatable: false);

    return parser;
  }();

  /// Creates a styled separator with the given [text].
  static String _separator(String text) =>
      _separatorBar * 3 +
      " " +
      (hasTerminal ? '\u001b[1m' : '') +
      text +
      (hasTerminal ? '\u001b[0m' : '') +
      ' ' +
      // Three separators + two spaces = 5
      _separatorBar * (_separatorLength - 5 - text.length);

  /// A human-readable description of how to invoke the Sass executable.
  static String get usage => _parser.usage;

  /// Shorthand for throwing a [UsageException] with the given [message].
  @alwaysThrows
  static void _fail(String message) => throw new UsageException(message);

  /// The parsed options passed by the user to the executable.
  final ArgResults _options;

  /// Whether to print the version of Sass and exit.
  bool get version => _options['version'] as bool;

  /// Whether to run an interactive shell.
  bool get interactive {
    if (_interactive != null) return _interactive;
    _interactive = _options['interactive'] as bool;
    if (!_interactive) return false;

    var invalidOptions = [
      'stdin', 'indented', 'load-path', 'style', 'source-map', //
      'source-map-urls', 'embed-sources', 'embed-source-map'
    ];
    for (var option in invalidOptions) {
      if (_options.wasParsed(option)) {
        throw new UsageException("--$option isn't allowed with --interactive.");
      }
    }
    return true;
  }

  bool _interactive;

  /// Whether to parse the source file with the indented syntax.
  ///
  /// This may be `null`, indicating that this should be determined by each
  /// stylesheet's extension.
  bool get indented => _ifParsed('indented') as bool;

  /// Whether to use ANSI terminal colors.
  bool get color =>
      _options.wasParsed('color') ? _options['color'] as bool : hasTerminal;

  /// Whether to silence normal output.
  bool get quiet => _options['quiet'] as bool;

  /// The logger to use to emit messages from Sass.
  Logger get logger => quiet ? Logger.quiet : new Logger.stderr(color: color);

  /// The style to use for the generated CSS.
  OutputStyle get style => _options['style'] == 'compressed'
      ? OutputStyle.compressed
      : OutputStyle.expanded;

  /// The set of paths Sass in which should look for imported files.
  List<String> get loadPaths => _options['load-path'] as List<String>;

  /// Whether to run the evaluator in asynchronous mode, for debugging purposes.
  bool get asynchronous => _options['async'] as bool;

  /// Whether to print the full Dart stack trace on exceptions.
  bool get trace => _options['trace'] as bool;

  /// Whether to update only files that have changed since the last compilation.
  bool get update => _options['update'] as bool;

  /// A map from source paths to the destination paths where the compiled CSS
  /// should be written.
  ///
  /// A `null` source indicates that a stylesheet should be read from standard
  /// input. A `null` destination indicates that a stylesheet should be written
  /// to standard output.
  ///
  /// A source path may refer to either a single stylesheet file, in which case
  /// the destination is the file where the resulting CSS should be written; or
  /// to a directory containing stylesheets, in which case the destination is a
  /// directory in which the compiled CSS should be written in the same
  /// structure.
  Map<String, String> get sourcesToDestinations {
    if (_sourcesToDestinations != null) return _sourcesToDestinations;

    var stdin = _options['stdin'] as bool;
    if (_options.rest.isEmpty && !stdin) _fail("Compile Sass to CSS.");

    var colonArgs = false;
    var positionalArgs = false;
    for (var argument in _options.rest) {
      if (argument.isEmpty) {
        _fail('Invalid argument "".');
      } else if (argument.contains(":")) {
        colonArgs = true;
      } else {
        positionalArgs = true;
      }
    }

    if (positionalArgs || _options.rest.isEmpty) {
      if (colonArgs) {
        _fail('Positional and ":" arguments may not both be used.');
      } else if (stdin) {
        if (_options.rest.length > 1) {
          _fail("Only one argument is allowed with --stdin.");
        } else if (update) {
          _fail("--update is not allowed with --stdin.");
        }
        return {null: _options.rest.isEmpty ? null : _options.rest.first};
      } else if (_options.rest.length > 2) {
        _fail("Only two positional args may be passed.");
      } else {
        var source = _options.rest.first == '-' ? null : _options.rest.first;
        var destination = _options.rest.length == 1 ? null : _options.rest.last;
        if (update && destination == null) {
          _fail("--update is not allowed when printing to stdout.");
        }

        return {source: destination};
      }
    }

    if (stdin) _fail('--stdin may not be used with ":" arguments.');

    // Track [seen] separately from `sourcesToDestinations.keys` because we want
    // to report errors for sources as users entered them, rather than after
    // directories have been resolved.
    var seen = new Set<String>();
    var sourcesToDestinations = <String, String>{};
    for (var argument in _options.rest) {
      var components = argument.split(":");
      if (components.length > 2) {
        _fail('"$argument" may only contain one ":".');
      }
      assert(components.length == 2);

      var source = components.first;
      var destination = components.last;
      if (!seen.add(source)) {
        _fail('Duplicate source "${source}".');
      }

      if (source == '-') {
        sourcesToDestinations[null] = destination;
      } else if (dirExists(source)) {
        sourcesToDestinations.addAll(_listSourceDirectory(source, destination));
      } else {
        sourcesToDestinations[source] = destination;
      }
    }
    _sourcesToDestinations = new Map.unmodifiable(sourcesToDestinations);
    return _sourcesToDestinations;
  }

  Map<String, String> _sourcesToDestinations;

  /// Returns the sub-map of [sourcesToDestinations] for the given [source] and
  /// [destination] directories.
  Map<String, String> _listSourceDirectory(String source, String destination) {
    var map = <String, String>{};
    for (var path in listDir(source)) {
      var basename = p.basename(path);
      if (basename.startsWith("_")) continue;

      var extension = p.extension(path);
      if (extension != ".scss" && extension != ".sass") continue;

      map[path] = p.join(
          destination, p.setExtension(p.relative(path, from: source), '.css'));
    }
    return map;
  }

  /// Whether to emit a source map file.
  bool get emitSourceMap {
    if (!(_options['source-map'] as bool)) {
      if (_options.wasParsed('source-map-urls')) {
        _fail("--source-map-urls isn't allowed with --no-source-map.");
      } else if (_options.wasParsed('embed-sources')) {
        _fail("--embed-sources isn't allowed with --no-source-map.");
      } else if (_options.wasParsed('embed-source-map')) {
        _fail("--embed-source-map isn't allowed with --no-source-map.");
      }
    }

    var writeToStdout = sourcesToDestinations.length == 1 &&
        sourcesToDestinations.values.single == null;
    if (!writeToStdout) return _options['source-map'] as bool;

    if (_ifParsed('source-map-urls') == 'relative') {
      _fail(
          "--source-map-urls=relative isn't allowed when printing to stdout.");
    }

    if (_options['embed-source-map'] as bool) {
      return _options['source-map'] as bool;
    } else if (_ifParsed('source-map') == true) {
      _fail(
          "When printing to stdout, --source-map requires --embed-source-map.");
    } else if (_options.wasParsed('source-map-urls')) {
      _fail("When printing to stdout, --source-map-urls requires "
          "--embed-source-map.");
    } else if (_options['embed-sources'] as bool) {
      _fail("When printing to stdout, --embed-sources requires "
          "--embed-source-map.");
    } else {
      return false;
    }
  }

  /// Whether to embed the generated source map as a data URL in the output CSS.
  bool get embedSourceMap => _options['embed-source-map'] as bool;

  /// Whether to embed the source files in the generated source map.
  bool get embedSources => _options['embed-sources'] as bool;

  /// Parses options from [args].
  ///
  /// Throws a [UsageException] if parsing fails.
  factory ExecutableOptions.parse(List<String> args) {
    try {
      var options = new ExecutableOptions._(_parser.parse(args));
      if (options._options['help'] as bool) _fail("Compile Sass to CSS.");
      return options;
    } on FormatException catch (error) {
      _fail(error.message);
    }
  }

  ExecutableOptions._(this._options);

  /// Makes [url] absolute or relative (to the directory containing
  /// [destination]) according to the `source-map-urls` option.
  Uri sourceMapUrl(Uri url, String destination) {
    var path = p.canonicalize(p.fromUri(url));
    return p.toUri(_options['source-map-urls'] == 'relative'
        ? p.relative(path, from: p.dirname(destination))
        : p.absolute(path));
  }

  /// Returns the value of [name] in [options] if it was explicitly provided by
  /// the user, and `null` otherwise.
  Object _ifParsed(String name) =>
      _options.wasParsed(name) ? _options[name] : null;
}

/// An exception indicating that invalid arguments were passed.
class UsageException implements Exception {
  final String message;

  UsageException(this.message);
}
