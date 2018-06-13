// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:collection';

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:watcher/watcher.dart';

import '../exception.dart';
import '../importer/filesystem.dart';
import '../io.dart';
import '../stylesheet_graph.dart';
import '../util/multi_dir_watcher.dart';
import 'compile_stylesheet.dart';
import 'options.dart';

/// Watches all the files in [graph] for changes and updates them as necessary.
Future watch(ExecutableOptions options, StylesheetGraph graph) async {
  var directoriesToWatch = <String>[]
    ..addAll(options.sourceDirectoriesToDestinations.keys)
    ..addAll(options.sourcesToDestinations.keys.map(p.dirname))
    ..addAll(options.loadPaths);

  var dirWatcher = new MultiDirWatcher();
  await Future.wait(directoriesToWatch.map((dir) {
    // If a directory doesn't exist, watch its parent directory so that we're
    // notified once it starts existing.
    while (!dirExists(dir)) dir = p.dirname(dir);
    return dirWatcher.watch(dir);
  }));

  // Before we start paying attention to changes, compile all the stylesheets as
  // they currently exist. This ensures that changes that come in update a
  // known-good state.
  var watcher = new _Watcher(options, graph);
  for (var source in options.sourcesToDestinations.keys) {
    var destination = options.sourcesToDestinations[source];
    graph.addCanonical(new FilesystemImporter('.'),
        p.toUri(p.canonicalize(source)), p.toUri(source));
    await watcher.compile(source, destination, ifModified: true);
  }

  print("Sass is watching for changes. Press Ctrl-C to stop.\n");
  await watcher.watch(dirWatcher);
}

/// Holds state that's shared across functions that react to changes on the
/// filesystem.
class _Watcher {
  final ExecutableOptions _options;

  final StylesheetGraph _graph;

  _Watcher(this._options, this._graph);

  /// Compiles the stylesheet at [source] to [destination], and prints any
  /// errors that occur.
  Future compile(String source, String destination,
      {bool ifModified: false}) async {
    try {
      await compileStylesheet(_options, _graph, source, destination,
          ifModified: ifModified);
    } on SassException catch (error, stackTrace) {
      _delete(destination);
      _printError(error.toString(color: _options.color), stackTrace);
    } on FileSystemException catch (error, stackTrace) {
      _printError("Error reading ${p.relative(error.path)}: ${error.message}.",
          stackTrace);
    }
  }

  /// Deletes the file at [path] and prints a message about it.
  void _delete(String path) {
    try {
      deleteFile(path);
      var buffer = new StringBuffer();
      if (_options.color) buffer.write("\u001b[33m");
      buffer.write("Deleted $path.");
      if (_options.color) buffer.write("\u001b[0m");
      print(buffer);
    } on FileSystemException {
      // If the file doesn't exist, that's fine.
    }
  }

  /// Prints [message] to standard error, with [stackTrace] if [_options.trace]
  /// is set.
  void _printError(String message, StackTrace stackTrace) {
    stderr.writeln(message);

    if (_options.trace) {
      stderr.writeln();
      stderr.writeln(new Trace.from(stackTrace).terse.toString().trimRight());
    }

    stderr.writeln();
  }

  /// Listens to `watcher.events` and updates the filesystem accordingly.
  ///
  /// Returns a future that will only complete if an unexpected error occurs.
  Future watch(MultiDirWatcher watcher) async {
    loop:
    await for (var event in _debounceEvents(watcher.events)) {
      var extension = p.extension(event.path);
      if (extension != '.sass' && extension != '.scss') continue;
      var url = p.toUri(p.canonicalize(event.path));

      switch (event.type) {
        case ChangeType.MODIFY:
          if (!_graph.nodes.containsKey(url)) continue loop;

          // Access the node ahead-of-time because it's possible that
          // `_graph.reload()` notices the file has been deleted and removes it
          // from the graph.
          var node = _graph.nodes[url];
          _graph.reload(url);
          await _recompileDownstream([node]);
          break;

        case ChangeType.ADD:
          await _retryPotentialImports(event.path);

          var destination = _destinationFor(event.path);
          if (destination == null) continue loop;

          _graph.addCanonical(
              new FilesystemImporter('.'), url, p.toUri(event.path));

          await compile(event.path, destination);
          break;

        case ChangeType.REMOVE:
          await _retryPotentialImports(event.path);
          if (!_graph.nodes.containsKey(url)) continue loop;

          var destination = _destinationFor(event.path);
          if (destination != null) _delete(destination);

          var downstream = _graph.nodes[url].downstream;
          _graph.remove(url);
          await _recompileDownstream(downstream);
          break;
      }
    }
  }

  /// Combine [WatchEvent]s that happen in quick succession.
  ///
  /// Otherwise, if a file is erased and then rewritten, we can end up reading
  /// the intermediate erased version.
  Stream<WatchEvent> _debounceEvents(Stream<WatchEvent> events) {
    return events
        .transform(debounceBuffer(new Duration(milliseconds: 25)))
        .expand((buffer) {
      var typeForPath = new p.PathMap<ChangeType>();
      for (var event in buffer) {
        var oldType = typeForPath[event.path];
        if (oldType == null) {
          typeForPath[event.path] = event.type;
        } else if (event.type == ChangeType.REMOVE) {
          typeForPath[event.path] = ChangeType.REMOVE;
        } else if (oldType != ChangeType.ADD) {
          typeForPath[event.path] = ChangeType.MODIFY;
        }
      }

      return typeForPath.keys
          .map((path) => new WatchEvent(typeForPath[path], path));
    });
  }

  /// Recompiles [nodes] and everything that transitively imports them, if
  /// necessary.
  Future _recompileDownstream(Iterable<StylesheetNode> nodes) async {
    var seen = new Set<StylesheetNode>();
    var toRecompile = new Queue<StylesheetNode>.from(nodes);

    while (!toRecompile.isEmpty) {
      var node = toRecompile.removeFirst();
      if (!seen.add(node)) continue;

      await _compileIfEntrypoint(node.canonicalUrl);
      toRecompile.addAll(node.downstream);
    }
  }

  /// Compiles the stylesheet at [url] to CSS if it's an entrypoint that's being
  /// watched.
  Future _compileIfEntrypoint(Uri url) async {
    if (url.scheme != 'file') return;

    var source = p.fromUri(url);
    var destination = _destinationFor(source);
    if (destination == null) return;

    await compile(source, destination);
  }

  /// If a Sass file at [source] should be compiled to CSS, returns the path to
  /// the CSS file it should be compiled to.
  ///
  /// Otherwise, returns `null`.
  String _destinationFor(String source) {
    var destination = _options.sourcesToDestinations[source];
    if (destination != null) return destination;
    if (p.basename(source).startsWith('_')) return null;

    for (var sourceDir in _options.sourceDirectoriesToDestinations.keys) {
      if (p.isWithin(sourceDir, source)) {
        return p.join(_options.sourceDirectoriesToDestinations[sourceDir],
            p.setExtension(p.relative(source, from: sourceDir), '.css'));
      }
    }

    return null;
  }

  /// Re-runs all imports in [_graph] that might refer to [path], and recompiles
  /// the files that contain those imports if they end up importing new
  /// stylesheets.
  Future _retryPotentialImports(String path) async {
    var name = _name(p.basename(path));
    var changed = <StylesheetNode>[];
    for (var node in _graph.nodes.values) {
      var importChanged = false;
      for (var url in node.upstream.keys) {
        if (_name(p.url.basename(url.path)) != name) continue;
        _graph.clearCanonicalize(url);

        // If the import produces a different canonicalized URL than it did
        // before, it changed and the stylesheet needs to be recompiled.
        if (!importChanged) {
          Uri newCanonicalUrl;
          try {
            newCanonicalUrl = _graph.importCache
                .canonicalize(url, node.importer, node.canonicalUrl)
                ?.item2;
          } catch (_) {
            // If the call to canonicalize failed, do nothing. We'll surface the
            // error more nicely when we try to recompile the file.
          }
          importChanged = newCanonicalUrl != node.upstream[url]?.canonicalUrl;
        }
      }
      if (importChanged) changed.add(node);
    }

    await _recompileDownstream(changed);
  }

  /// Removes an extension from [extension], and a leading underscore if it has one.
  String _name(String basename) {
    basename = p.withoutExtension(basename);
    return basename.startsWith("_") ? basename.substring(1) : basename;
  }
}
