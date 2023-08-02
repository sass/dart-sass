// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_style/dart_style.dart';
import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import 'package:sass/src/util/nullable.dart';

/// The files to compile to synchronous versions.
final sources = const {
  'lib/src/visitor/async_evaluate.dart': 'lib/src/visitor/evaluate.dart',
  'lib/src/async_compile.dart': 'lib/src/compile.dart',
  'lib/src/async_environment.dart': 'lib/src/environment.dart',
  'lib/src/async_import_cache.dart': 'lib/src/import_cache.dart'
};

/// Classes that are defined in the async version of a file and used as-is in
/// the sync version, and thus should not be copied over.
final _sharedClasses = const ['EvaluateResult'];

/// This is how we support both synchronous and asynchronous compilation modes.
///
/// Both modes are necessary. Synchronous mode is faster, works in sync-only
/// contexts, and allows us to support Node Sass's renderSync() method.
/// Asynchronous mode allows users to write async importers and functions in
/// both Dart and JS.
///
/// The logic for synchronous and asynchronous mode is identical, but the async
/// code needs to await every statement and expression evaluation in case they
/// do asynchronous work. To avoid duplicating logic, we hand-write asynchronous
/// code for the evaluator and the environment and use this task to compile it
/// to a synchronous equivalent.
@Task('Compile async code to synchronous code.')
void synchronize() {
  sources.forEach((source, target) =>
      File(target).writeAsStringSync(synchronizeFile(source)));
}

/// Returns the result of synchronizing [source].
String synchronizeFile(String source) {
  source = p.absolute(source);
  var visitor = _Visitor(File(source).readAsStringSync(), source);

  parseFile(path: source, featureSet: FeatureSet.latestLanguageVersion())
      .unit
      .accept(visitor);
  return DartFormatter().format(visitor.result);
}

/// The visitor that traverses the asynchronous parse tree and converts it to
/// synchronous code.
///
/// To preserve the original whitespace and comments, this copies text from the
/// original source where possible. It tracks the [_position] at the end of the
/// text that's been written, and writes from that position to the new position
/// whenever text needs to be emitted.
class _Visitor extends RecursiveAstVisitor<void> {
  /// The source of the original asynchronous file.
  final String _source;

  /// The path from which [_source] was loaded.
  final String _path;

  /// The current position in [_source].
  var _position = 0;

  /// The buffer in which the text of the synchronous file is built up.
  final _buffer = StringBuffer();

  /// Returns the [SourceFile] which is being rewritten.
  ///
  /// This is only used for debugging and error reporting.
  SourceFile get _sourceFile =>
      SourceFile.fromString(_source, url: p.toUri(_path));

  /// The synchronous text.
  String get result {
    _buffer.write(_source.substring(_position));
    _position = _source.length;
    return _buffer.toString();
  }

  _Visitor(this._source, this._path) {
    var afterHeader = "\n".allMatches(_source).skip(3).first.end;
    _buffer.writeln(_source.substring(0, afterHeader));
    _buffer.writeln("""
// DO NOT EDIT. This file was generated from ${p.basename(_path)}.
// See tool/grind/synchronize.dart for details.
//
// Checksum: ${sha1.convert(utf8.encode(_source))}
//
// ignore_for_file: unused_import
""");

    if (p.basename(_path) == 'async_evaluate.dart') {
      _buffer.writeln();
      _buffer.writeln("import 'async_evaluate.dart' show EvaluateResult;");
      _buffer.writeln("export 'async_evaluate.dart' show EvaluateResult;");
      _buffer.writeln();
    } else if (p.basename(_path) == 'async_compile.dart') {
      _buffer.writeln();
      _buffer.writeln("export 'async_compile.dart';");
      _buffer.writeln();
    }

    _position = afterHeader;
  }

  void visitAwaitExpression(AwaitExpression node) {
    _skip(node.awaitKeyword);

    // Skip the space after "await" to work around dart-lang/dart_style#226.
    _position++;
    node.expression.accept(this);
  }

  void visitParenthesizedExpression(ParenthesizedExpression node) {
    if (node.expression is AwaitExpression) {
      _skip(node.leftParenthesis);
      node.expression.accept(this);
      _skip(node.rightParenthesis);
    } else {
      node.expression.accept(this);
    }
  }

  void visitBlockFunctionBody(BlockFunctionBody node) {
    _skip(node.keyword);
    node.visitChildren(this);
  }

  void visitClassDeclaration(ClassDeclaration node) {
    if (_sharedClasses.contains(node.name.lexeme)) {
      _skipNode(node);
    } else {
      for (var child in node.sortedCommentAndAnnotations) {
        child.accept(this);
      }
      _rename(node.name);
      node.typeParameters?.accept(this);
      node.extendsClause?.accept(this);
      node.withClause?.accept(this);
      node.implementsClause?.accept(this);
      node.nativeClause?.accept(this);
      node.members.accept(this);
    }
  }

  void visitGenericTypeAlias(GenericTypeAlias node) {
    if (_sharedClasses.contains(node.name.lexeme)) {
      _skipNode(node);
    } else {
      for (var child in node.sortedCommentAndAnnotations) {
        child.accept(this);
      }
      _rename(node.name);
      node.typeParameters?.accept(this);
      node.type.accept(this);
    }
  }

  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    _skip(node.keyword);
    node.visitChildren(this);
  }

  void visitFunctionDeclaration(FunctionDeclaration node) {
    for (var child in node.sortedCommentAndAnnotations) {
      child.accept(this);
    }
    node.returnType?.accept(this);
    _rename(node.name);
    node.functionExpression.accept(this);
  }

  void visitMethodDeclaration(MethodDeclaration node) {
    if (_synchronizeName(node.name.lexeme) != node.name.lexeme) {
      // If the file defines any asynchronous versions of synchronous functions,
      // remove them.
      _skipNode(node);
    } else {
      super.visitMethodDeclaration(node);
    }
  }

  void visitImportDirective(ImportDirective node) {
    _skipNode(node);
    var text = node.toString();
    if (!text.contains("dart:async")) {
      _buffer.write(text.replaceAll("async_", ""));
    }
  }

  void visitMethodInvocation(MethodInvocation node) {
    // Convert async utility methods to their synchronous equivalents.
    if (node
        case MethodInvocation(
          target: null,
          methodName: SimpleIdentifier(name: "mapAsync" || "putIfAbsentAsync")
        )) {
      _writeTo(node);
      var arguments = node.argumentList.arguments;
      _write(arguments.first);

      _buffer.write(".${_synchronizeName(node.methodName.name)}");
      node.typeArguments.andThen(_write);
      _buffer.write("(");

      _position = arguments[1].beginToken.offset;
      for (var argument in arguments.skip(1)) {
        argument.accept(this);
      }
    } else {
      super.visitMethodInvocation(node);
    }
  }

  void visitSimpleIdentifier(SimpleIdentifier node) {
    _skip(node.token);
    _buffer.write(_synchronizeName(node.name));
  }

  void visitNamedType(NamedType node) {
    if (node.name2.lexeme case "Future" || "FutureOr") {
      _skip(node.name2);
      if (node.typeArguments case var typeArguments?) {
        _skip(typeArguments.leftBracket);
        typeArguments.arguments.first.accept(this);
        _skip(typeArguments.rightBracket);
      } else {
        _buffer.write("void");
      }
    } else if (node.name2.lexeme == "Module") {
      _skipNode(node);
      _buffer.write("Module<Callable>");
    } else {
      super.visitNamedType(node);
    }
  }

  /// Writes through [node]'s (synchronized) name.
  ///
  /// Assumes [node] has a name field with type [Token].
  void _rename(Token token) {
    _skip(token);
    _buffer.write(_synchronizeName(token.lexeme));
  }

  /// Writes [_source] to [_buffer] up to the beginning of [token], then puts
  /// [_position] after [token] so it doesn't get written.
  void _skip(Token? token) {
    if (token == null) return;
    if (token.offset < _position) {
      throw _alreadyEmittedException(_spanForToken(token));
    }

    _buffer.write(_source.substring(_position, token.offset));
    _position = token.end;
  }

  /// Writes [_source] to [_buffer] up to the beginning of [node], then puts
  /// [_position] after [node] so it doesn't get written.
  void _skipNode(AstNode node) {
    _writeTo(node);
    _position = node.endToken.end;
  }

  /// Writes [_source] to [_buffer] up to the beginning of [node].
  void _writeTo(AstNode node) {
    if (node.beginToken.offset < _position) {
      throw _alreadyEmittedException(_spanForNode(node));
    }

    _buffer.write(_source.substring(_position, node.beginToken.offset));
    _position = node.beginToken.offset;
  }

  /// Writes the contents of [node] to [_buffer].
  ///
  /// This leaves [_position] at the end of [node].
  void _write(AstNode node) {
    if (node.beginToken.offset < _position) {
      throw _alreadyEmittedException(_spanForNode(node));
    }

    _position = node.beginToken.offset;
    node.accept(this);
    _buffer.write(_source.substring(_position, node.endToken.end));
    _position = node.endToken.end;
  }

  /// Strips an "async" prefix or suffix from [name].
  String _synchronizeName(String name) {
    if (name.toLowerCase().startsWith('async')) {
      return name.substring('async'.length);
    } else if (name.toLowerCase().endsWith('async')) {
      return name.substring(0, name.length - 'async'.length);
    } else {
      return name;
    }
  }

  SourceSpanException _alreadyEmittedException(SourceSpan span) {
    var lines = _buffer.toString().split("\n");
    return SourceSpanException(
        "Node was already emitted. Last 3 lines:\n\n" +
            lines
                .slice(math.max(lines.length - 3, 0))
                .map((line) => "  $line")
                .join("\n") +
            "\n",
        span);
  }

  /// Returns a [FileSpan] that represents [token]'s position in the source
  /// file.
  SourceSpan _spanForToken(Token token) =>
      _sourceFile.span(token.offset, token.end);

  /// Returns a [FileSpan] that represents [token]'s position in the source
  /// file.
  SourceSpan _spanForNode(AstNode node) =>
      _sourceFile.span(node.beginToken.offset, node.endToken.end);
}
