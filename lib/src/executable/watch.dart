// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;
import 'package:stream_transform/stream_transform.dart';
import 'package:watcher/watcher.dart';

import '../importer/filesystem.dart';
import '../io.dart';
import '../stylesheet_graph.dart';
import '../util/map.dart';
import '../util/multi_dir_watcher.dart';
import 'concurrent.dart';
import 'options.dart';

/// Watches all the files in [graph] for changes and updates them as necessary.
Future<void> watch(ExecutableOptions options, StylesheetGraph graph) async {
  var directoriesToWatch = [
    ..._sourceDirectoriesToDestinations(options).keys,
    for (var dir in _sourcesToDestinations(options).keys) p.dirname(dir),
    ...options.loadPaths,
  ];

  var dirWatcher = MultiDirWatcher(poll: options.poll);
  await Future.wait(
    directoriesToWatch.map((dir) {
      // If a directory doesn't exist, watch its parent directory so that we're
      // notified once it starts existing.
      while (!dirExists(dir)) {
        dir = p.dirname(dir);
      }
      return dirWatcher.watch(dir);
    }),
  );

  // Before we start paying attention to changes, compile all the stylesheets as
  // they currently exist. This ensures that changes that come in update a
  // known-good state.
  var watcher = _Watcher(options, graph);
  var sourcesToDestinations = _sourcesToDestinations(options);
  for (var source in sourcesToDestinations.keys) {
    graph.addCanonical(
      FilesystemImporter.cwd,
      p.toUri(canonicalize(source)),
      p.toUri(source),
      recanonicalize: false,
    );
  }
  var success = await compileStylesheets(
    options,
    graph,
    sourcesToDestinations,
    ifModified: true,
  );
  if (!success && options.stopOnError) {
    dirWatcher.events.listen(null).cancel();
    return;
  }

  print("Sass is watching for changes. Press Ctrl-C to stop.\n");
  await watcher.watch(dirWatcher);
}

/// Holds state that's shared across functions that react to changes on the
/// filesystem.
final class _Watcher {
  /// The options for the Sass executable.
  final ExecutableOptions _options;

  /// The graph of stylesheets being compiled.
  final StylesheetGraph _graph;

  /// A map from source paths to destinations that need to be recompiled once
  /// the current batch of events has been processed.
  final Map<String, String> _toRecompile = {};

  _Watcher(this._options, this._graph);

  /// Deletes the file at [path] and prints a message about it.
  void _delete(String path) {
    try {
      deleteFile(path);
      var buffer = StringBuffer();
      if (_options.color) buffer.write("\u001b[33m");
      buffer.write("Deleted $path.");
      if (_options.color) buffer.write("\u001b[0m");
      print(buffer);
    } on FileSystemException {
      // If the file doesn't exist, that's fine.
    }
  }

  /// Listens to `watcher.events` and updates the filesystem accordingly.
  ///
  /// Returns a future that will only complete if an unexpected error occurs.
  Future<void> watch(MultiDirWatcher watcher) async {
    await for (var batch in _debounceEvents(watcher.events)) {
      for (var event in batch) {
        var extension = p.extension(event.path);
        if (extension != '.sass' &&
            extension != '.scss' &&
            extension != '.css') {
          continue;
        }

        switch (event.type) {
          case ChangeType.MODIFY:
            _handleModify(event.path);

          case ChangeType.ADD:
            _handleAdd(event.path);

          case ChangeType.REMOVE:
            _handleRemove(event.path);
        }
      }

      var toRecompile = {..._toRecompile};
      _toRecompile.clear();
      var success = await compileStylesheets(
        _options,
        _graph,
        toRecompile,
        ifModified: true,
      );
      if (!success && _options.stopOnError) return;
    }
  }

  /// Handles a modify event for the stylesheet at [path].
  ///
  /// Returns whether all necessary recompilations succeeded.
  void _handleModify(String path) {
    var url = _canonicalize(path);

    // It's important to access the node ahead-of-time because it's possible
    // that `_graph.reload()` notices the file has been deleted and removes it
    // from the graph.
    if (_graph.nodes[url] case var node?) {
      _graph.reload(url);
      _recompileDownstream([node]);
    } else {
      _handleAdd(path);
    }
  }

  /// Handles an add event for the stylesheet at [url].
  ///
  /// Returns whether all necessary recompilations succeeded.
  void _handleAdd(String path) {
    var destination = _destinationFor(path);
    if (destination != null) _toRecompile[path] = destination;
    var downstream = _graph.addCanonical(
      FilesystemImporter.cwd,
      _canonicalize(path),
      p.toUri(path),
    );
    _recompileDownstream(downstream);
  }

  /// Handles a remove event for the stylesheet at [url].
  ///
  /// Returns whether all necessary recompilations succeeded.
  void _handleRemove(String path) async {
    var url = _canonicalize(path);

    if (_graph.nodes.containsKey(url)) {
      if (_destinationFor(path) case var destination?) _delete(destination);
    }

    var downstream = _graph.remove(FilesystemImporter.cwd, url);
    _recompileDownstream(downstream);
  }

  /// Returns the canonical URL for the stylesheet path [path].
  Uri _canonicalize(String path) => p.toUri(canonicalize(path));

  /// Combine [WatchEvent]s that happen in quick succession.
  ///
  /// Otherwise, if a file is erased and then rewritten, we can end up reading
  /// the intermediate erased version. This returns a stream of batches of
  /// events that all happened in succession.
  Stream<List<WatchEvent>> _debounceEvents(Stream<WatchEvent> events) {
    return events.debounceBuffer(Duration(milliseconds: 25)).map((buffer) {
      var typeForPath = p.PathMap<ChangeType>();
      for (var event in buffer) {
        var oldType = typeForPath[event.path];
        typeForPath[event.path] = switch ((oldType, event.type)) {
          (null, var newType) => newType,
          (_, ChangeType.REMOVE) => ChangeType.REMOVE,
          (ChangeType.ADD, _) => ChangeType.ADD,
          (_, _) => ChangeType.MODIFY,
        };
      }

      return [
        // PathMap always has nullable keys
        for (var (path!, type) in typeForPath.pairs) WatchEvent(type, path),
      ];
    });
  }

  /// Marks [nodes] and everything that transitively imports them for
  /// recompilation, if necessary.
  void _recompileDownstream(Iterable<StylesheetNode> nodes) {
    var seen = <StylesheetNode>{};
    while (nodes.isNotEmpty) {
      nodes = [
        for (var node in nodes)
          if (seen.add(node)) node,
      ];

      _toRecompile.addAll(_sourceEntrypointsToDestinations(nodes));

      nodes = [for (var node in nodes) ...node.downstream];
    }
  }

  /// Returns a sourcesToDestinations mapping for nodes that are entrypoints.
  Map<String, String> _sourceEntrypointsToDestinations(
    Iterable<StylesheetNode> nodes,
  ) {
    var entrypoints = <String, String>{};
    for (var node in nodes) {
      var url = node.canonicalUrl;
      if (url.scheme != 'file') continue;

      var source = p.fromUri(url);
      if (_destinationFor(source) case var destination?) {
        entrypoints[source] = destination;
      }
    }
    return entrypoints;
  }

  /// If a Sass file at [source] should be compiled to CSS, returns the path to
  /// the CSS file it should be compiled to.
  ///
  /// Otherwise, returns `null`.
  String? _destinationFor(String source) {
    if (_sourcesToDestinations(_options)[source] case var destination?) {
      return destination;
    }
    if (p.basename(source).startsWith('_')) return null;

    for (var (sourceDir, destinationDir)
        in _sourceDirectoriesToDestinations(_options).pairs) {
      if (!p.isWithin(sourceDir, source)) continue;

      var destination = p.join(
        destinationDir,
        p.setExtension(p.relative(source, from: sourceDir), '.css'),
      );

      // Don't compile ".css" files to their own locations.
      if (!p.equals(destination, source)) return destination;
    }

    return null;
  }
}

/// Exposes [options.sourcesToDestinations] as a non-nullable map, since stdin
/// inputs and stdout outputs aren't allowed in `--watch` mode.
Map<String, String> _sourcesToDestinations(ExecutableOptions options) =>
    options.sourcesToDestinations.cast<String, String>();

/// Exposes [options.sourcesDirectoriesToDestinations] as a non-nullable map,
/// since stdin inputs and stdout outputs aren't allowed in `--watch` mode.
Map<String, String> _sourceDirectoriesToDestinations(
  ExecutableOptions options,
) =>
    options.sourceDirectoriesToDestinations.cast<String, String>();
