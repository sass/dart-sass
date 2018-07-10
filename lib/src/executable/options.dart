// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:args/args.dart';
import 'package:charcode/charcode.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../sass.dart';
import '../io.dart';
import '../util/character.dart';

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
      ..addFlag('watch',
          help: 'Watch stylesheets and recompile when they change.',
          negatable: false)
      ..addFlag('poll',
          help: 'Manually check for changes rather than using a native '
              'watcher.\n'
              'Only valid with --watch.')
      ..addFlag('stop-on-error',
          help: "Don't compile more files once an error is encountered.")
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
      'source-map-urls', 'embed-sources', 'embed-source-map', 'update', 'watch'
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
  bool get color => _options.wasParsed('color')
      ? _options['color'] as bool
      : supportsAnsiEscapes;

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

  /// Whether to continuously watch the filesystem for changes.
  bool get watch => _options['watch'] as bool;

  /// Whether to manually poll for changes when watching.
  bool get poll => _options['poll'] as bool;

  /// Whether to stop compiling additional files once one file produces an
  /// error.
  bool get stopOnError => _options['stop-on-error'] as bool;

  /// A map from source paths to the destination paths where the compiled CSS
  /// should be written.
  ///
  /// Considers keys to be the same if they represent the same path on disk.
  ///
  /// A `null` source indicates that a stylesheet should be read from standard
  /// input. A `null` destination indicates that a stylesheet should be written
  /// to standard output.
  Map<String, String> get sourcesToDestinations {
    _ensureSources();
    return _sourcesToDestinations;
  }

  Map<String, String> _sourcesToDestinations;

  /// A map from source directories to the destination directories where the
  /// compiled CSS for stylesheets in the source directories should be written.
  ///
  /// Considers keys to be the same if they represent the same path on disk.
  Map<String, String> get sourceDirectoriesToDestinations {
    _ensureSources();
    return _sourceDirectoriesToDestinations;
  }

  Map<String, String> _sourceDirectoriesToDestinations;

  /// Ensure that both [sourcesToDestinations] and [sourceDirectories] have been
  /// computed.
  void _ensureSources() {
    if (_sourcesToDestinations != null) return;

    var stdin = _options['stdin'] as bool;
    if (_options.rest.isEmpty && !stdin) _fail("Compile Sass to CSS.");

    var colonArgs = false;
    var positionalArgs = false;
    for (var argument in _options.rest) {
      if (argument.isEmpty) _fail('Invalid argument "".');

      // If the colon appears at position 1, treat it as a Windows drive
      // letter.
      if (!argument.contains(":") ||
          (_isWindowsPath(argument, 0) &&
              // Look for colons after index 1, since that's where the drive
              // letter is on Windows paths.
              argument.indexOf(":", 2) == -1)) {
        positionalArgs = true;
      } else {
        colonArgs = true;
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
        } else if (watch) {
          _fail("--watch is not allowed with --stdin.");
        }
        _sourcesToDestinations = new Map.unmodifiable(
            {null: _options.rest.isEmpty ? null : _options.rest.first});
      } else if (_options.rest.length > 2) {
        _fail("Only two positional args may be passed.");
      } else {
        var source = _options.rest.first == '-' ? null : _options.rest.first;
        var destination = _options.rest.length == 1 ? null : _options.rest.last;
        if (destination == null) {
          if (update) {
            _fail("--update is not allowed when printing to stdout.");
          } else if (watch) {
            _fail("--watch is not allowed when printing to stdout.");
          }
        }
        _sourcesToDestinations =
            new UnmodifiableMapView(new p.PathMap.of({source: destination}));
      }
      _sourceDirectoriesToDestinations = const {};
      return;
    }

    if (stdin) _fail('--stdin may not be used with ":" arguments.');

    // Track [seen] separately from `sourcesToDestinations.keys` because we want
    // to report errors for sources as users entered them, rather than after
    // directories have been resolved.
    var seen = new Set<String>();
    var sourcesToDestinations = new p.PathMap<String>();
    var sourceDirectoriesToDestinations = new p.PathMap<String>();
    for (var argument in _options.rest) {
      String source;
      String destination;
      for (var i = 0; i < argument.length; i++) {
        // A colon at position 1 may be a Windows drive letter and not a
        // separator.
        if (i == 1 && _isWindowsPath(argument, i - 1)) continue;

        if (argument.codeUnitAt(i) == $colon) {
          if (source == null) {
            source = argument.substring(0, i);
            destination = argument.substring(i + 1);
          } else if (i != source.length + 2 ||
              !_isWindowsPath(argument, i - 1)) {
            // A colon 2 character after the separator may also be a Windows
            // drive letter.
            _fail('"$argument" may only contain one ":".');
          }
        }
      }

      if (!seen.add(source)) {
        _fail('Duplicate source "${source}".');
      }

      if (source == '-') {
        sourcesToDestinations[null] = destination;
      } else if (dirExists(source)) {
        sourceDirectoriesToDestinations[source] = destination;
        sourcesToDestinations.addAll(_listSourceDirectory(source, destination));
      } else {
        sourcesToDestinations[source] = destination;
      }
    }
    _sourcesToDestinations = new UnmodifiableMapView(sourcesToDestinations);
    _sourceDirectoriesToDestinations =
        new UnmodifiableMapView(sourceDirectoriesToDestinations);
  }

  /// Returns whether [string] contains an absolute Windows path at [index].
  bool _isWindowsPath(String string, int index) =>
      string.length > index + 2 &&
      isAlphabetic(string.codeUnitAt(index)) &&
      string.codeUnitAt(index + 1) == $colon;

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

  ExecutableOptions._(this._options) {
    if (_options.wasParsed('poll') && !watch) {
      _fail("--poll may not be passed without --watch.");
    }
  }

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
