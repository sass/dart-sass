@TestOn('browser')

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

  test('compileString() throws error if importing without custom importer', () {
    expect(() => sass.compileString("@use 'other';"),
        throwsA(predicate((error) {
      expect(error.toString(), matches("Can't find stylesheet to import."));
      return true;
    })));
  });

  test('compileStringAsync() throws error if importing without custom importer',
      () async {
    var result = sass.compileStringAsync("@use 'other';");
    expect(() async => await promiseToFuture<NodeCompileResult>(result),
        throwsA(predicate((error) {
      expect(error.toString(), matches("Can't find stylesheet to import."));
      return true;
    })));
  });
}
