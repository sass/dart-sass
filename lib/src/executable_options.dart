// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:args/args.dart';
import 'package:meta/meta.dart';

import '../sass.dart';
import 'io.dart';
import 'util/path.dart';

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
          defaultsTo: 'expanded');

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
    if (!(_options['interactive'] as bool)) return false;
    if (_options.wasParsed('stdin') ||
        _options.wasParsed('indented') ||
        _options.wasParsed('load-path') ||
        _options.wasParsed('style') ||
        _options.wasParsed('quiet') ||
        _options.wasParsed('help') ||
        _options.wasParsed('source-map') ||
        _options.wasParsed('source-map-urls') ||
        _options.wasParsed('embed-sources') ||
        _options.wasParsed('embed-source-map')) {
      throw new UsageException("Option not supported with --interactive.");
    }
    return true;
  }

  /// Whether to parse the source file with the indented syntax.
  bool get indented =>
      _ifParsed('indented') as bool ??
      (source != null && p.extension(source) == '.sass');

  /// Whether to use ANSI terminal colors.
  bool get color =>
      _options.wasParsed('color') ? _options['color'] as bool : hasTerminal;

  /// The logger to use to emit messages from Sass.
  Logger get logger => _options['quiet'] as bool
      ? Logger.quiet
      : new Logger.stderr(color: color);

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

  /// The entrypoint Sass file, or `null` if the source should be read from
  /// stdin.
  String get source {
    _ensureSourceAndDestination();
    return _source;
  }

  String _source;

  /// Whether to read the source file from stdin rather than a file on disk.
  bool get readFromStdin => source == null;

  /// The path to which to write the CSS, or `null` if the CSS should be printed
  /// to stdout.
  String get destination {
    _ensureSourceAndDestination();
    return _destination;
  }

  String _destination;

  /// Whether to write the output CSS to stdout rather than a file on disk.
  bool get writeToStdout => destination == null;

  /// Whether [_source] and [_destination] have been parsed from [_options] yet.
  var _parsedSourceAndDestination = false;

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

    if (destination != null) return _options['source-map'] as bool;

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

  /// Parses [source] and [destination] from [_options] if they haven't been
  /// parsed yet.
  void _ensureSourceAndDestination() {
    if (_parsedSourceAndDestination) return;
    _parsedSourceAndDestination = true;

    if (_options['stdin'] as bool) {
      if (_options.rest.length > 1) _fail("Compile Sass to CSS.");
      if (_options.rest.isNotEmpty) _destination = _options.rest.first;
    } else if (_options.rest.isEmpty || _options.rest.length > 2) {
      _fail("Compile Sass to CSS.");
    } else if (_options.rest.first == '-') {
      if (_options.rest.length > 1) _destination = _options.rest.last;
    } else {
      _source = _options.rest.first;
      if (_options.rest.length > 1) _destination = _options.rest.last;
    }
  }

  /// Makes [url] absolute or relative (to [dir]) according to the
  /// `source-map-urls` option.
  Uri sourceMapUrl(Uri url) {
    var path = p.fromUri(url);
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
