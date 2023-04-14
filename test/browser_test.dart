@TestOn('browser')

import 'package:js/js.dart';
import 'package:node_interop/js.dart';
import 'package:node_interop/util.dart';
import 'package:sass/src/node/compile_options.dart';
import 'package:sass/src/node/legacy/render_options.dart';
import 'package:sass/src/node/legacy/render_result.dart';
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
  external NodeCompileResult compile(String path, [CompileOptions? options]);
  external Promise compileAsync(String path, [CompileOptions? options]);
  external void render(
      RenderOptions options, void callback(Error error, RenderResult result));
  external RenderResult renderSync(RenderOptions options);
  external String get info;
}

void main() {
  setUpAll(ensureNpmPackage);

  test('compileAsync() is not available', () {
    expect(() => sass.compileAsync('index.scss'), throwsA(predicate((error) {
      expect(error, const TypeMatcher<JsError>());
      expect(
          error.toString(),
          startsWith(
              "Error: The compileAsync() method is only available in Node.js."));
      return true;
    })));
  });

  test('compile() is not available', () {
    expect(() => sass.compile('index.scss'), throwsA(predicate((error) {
      expect(error, const TypeMatcher<JsError>());
      expect(
          error.toString(),
          startsWith(
              "Error: The compile() method is only available in Node.js."));
      return true;
    })));
  });

  test('render() is not available', () {
    expect(() => sass.render(RenderOptions(), allowInterop((error, result) {})),
        throwsA(predicate((error) {
      expect(error, const TypeMatcher<JsError>());
      expect(
          error.toString(),
          startsWith(
              "Error: The render() method is only available in Node.js."));
      return true;
    })));
  });

  test('renderSync() is not available', () {
    expect(() => sass.renderSync(RenderOptions()), throwsA(predicate((error) {
      expect(error, const TypeMatcher<JsError>());
      expect(
          error.toString(),
          startsWith(
              "Error: The renderSync() method is only available in Node.js."));
      return true;
    })));
  });

  test('info produces output', () {
    expect(sass.info, startsWith("dart-sass\t"));
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
      expect(error, const TypeMatcher<JsError>());
      expect(
          error.toString(),
          startsWith(
              "Custom importers are required to load stylesheets when compiling in the browser."));
      return true;
    })));
  });

  test('compileStringAsync() throws error if importing without custom importer',
      () async {
    var result = sass.compileStringAsync("@use 'other';");
    expect(() async => await promiseToFuture<NodeCompileResult>(result),
        throwsA(predicate((error) {
      expect(error, const TypeMatcher<JsError>());
      expect(
          error.toString(),
          startsWith(
              "Custom importers are required to load stylesheets when compiling in the browser."));
      return true;
    })));
  });
}
