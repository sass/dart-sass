@TestOn('browser')

import 'dart:js';

import 'package:js/js.dart';
import 'package:node_interop/js.dart';
import 'package:node_interop/util.dart';
import 'package:sass/src/node/compile_options.dart';
import 'package:test/test.dart';
import 'ensure_npm_package.dart';
import 'package:sass/src/node/compile_result.dart';

@JS()
external Sass get sass;

@JS()
class Sass {
  external NodeCompileResult compileString(String text,
      [CompileStringOptions? options]);
  external Promise compileStringAsync(String text,
      [CompileStringOptions? options]);
}

void main() {
  setUpAll(ensureNpmPackage);
  test('compileAsync() is not available', () {
    expect(() => (sass as dynamic).compileAsync,
        throwsA(isA<NoSuchMethodError>()));
  });
  test('compile() is not available', () {
    expect(() => (sass as dynamic).compile, throwsA(isA<NoSuchMethodError>()));
  });
  test('render() is not available', () {
    expect(() => (sass as dynamic).render, throwsA(isA<NoSuchMethodError>()));
  });
  test('renderSync() is not available', () {
    expect(
        () => (sass as dynamic).renderSync, throwsA(isA<NoSuchMethodError>()));
  });
  test('compileString() produces output', () {
    var result = sass.compileString('foo {bar: baz}');
    expect(result.css, equals('foo {\n  bar: baz;\n}'));
  });
  test('compileStringAsync() produces output', () async {
    var result = sass.compileStringAsync('foo {bar: baz}');
    result = await promiseToFuture(result);
    expect((result as NodeCompileResult).css, equals('foo {\n  bar: baz;\n}'));
  });
}
