// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:args/args.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:path/path.dart' as p;

import 'package:sass/src/exception.dart';
import 'package:sass/src/parser.dart';
import 'package:sass/src/visitor/perform.dart';
import 'package:sass/src/visitor/serialize.dart';

void main(List<String> args) {
  var argParser = new ArgParser(allowTrailingOptions: true)
    ..addOption('precision', hide: true)
    ..addOption('style',
        abbr: 's',
        help: 'Output style.',
        allowed: ['expanded'],
        defaultsTo: 'expanded')
    ..addFlag('trace', help: 'Print full Dart stack traces for exceptions.')
    ..addFlag('help',
        abbr: 'h', help: 'Print this usage information.', negatable: false);
  var options = argParser.parse(args);

  if (options['help']) {
    print("Compile Sass to CSS.\n");
    print("Usage: sass <input>\n");
    print(argParser.usage);
    exit(64);
  }

  try {
    var file = options.rest.first;
    var parser =
        new Parser(new File(file).readAsStringSync(), url: p.toUri(file));
    var cssTree = new PerformVisitor().visitStylesheet(parser.parse());
    var css = toCss(cssTree);
    if (css.isNotEmpty) print(css);
  } on SassException catch (error, stackTrace) {
    stderr.writeln(error.toString(color: true));

    if (options['trace']) {
      stderr.writeln();
      stderr.write(new Trace.from(stackTrace));
      stderr.flush();
    }

    exit(1);
  }
}
