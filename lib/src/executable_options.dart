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
      ..addSeparator(_separator('Other'))
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
