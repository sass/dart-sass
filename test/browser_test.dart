@Tags(['browser'])

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
  test('sass object is available', () {
    expect(sass, isNotNull);
  });
  test('compileString() is available', () {
    expect(sass.compileString, isNotNull);
  });
  test('compileStringAsync() is available', () {
    expect(sass.compileStringAsync, isNotNull);
  });
  // test('compile() is not available', () {
  //   expect(sass.compile, isNull);
  // });
  // test('render() is not available', () {
  //   expect(sass.render, isNull);
  // });
  // test('renderSync() is not available', () {
  //   expect(sass.renderSync, isNull);
  // });
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
