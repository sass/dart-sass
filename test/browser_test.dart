@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:js_core/js_core.dart';
import 'package:sass/src/js/compile_options.dart';
import 'package:sass/src/js/compile_result.dart';
import 'package:sass/src/js/legacy/render_options.dart';
import 'package:sass/src/js/legacy/render_result.dart';
import 'package:test/test.dart';

import 'ensure_npm_package.dart';

@JS()
external Sass get sass;

@JS()
class Sass {
  external JSCompileResult compileString(
    String text, [
    SyncCompileOptions? options,
  ]);
  external JSPromise<JSCompileResult> compileStringAsync(
    String text, [
    AsyncCompileOptions? options,
  ]);
  external JSCompileResult compile(String path, [SyncCompileOptions? options]);
  external JSPromise<JSCompileResult> compileAsync(String path,
      [AsyncCompileOptions? options]);
  external void render(
    RenderOptions options,
    JSFunction callback,
  );
  external RenderResult renderSync(RenderOptions options);
  external String get info;
}

void main() {
  setUpAll(ensureNpmPackage);

  test('compileAsync() is not available', () {
    expect(
      () => sass.compileAsync('index.scss'),
      throwsA(
        predicate((error) {
          expect(error, const TypeMatcher<JSError>());
          expect(
            error.toString(),
            startsWith(
              "Error: The compileAsync() method is only available in Node.js.",
            ),
          );
          return true;
        }),
      ),
    );
  });

  test('compile() is not available', () {
    expect(
      () => sass.compile('index.scss'),
      throwsA(
        predicate((error) {
          expect(error, const TypeMatcher<JSError>());
          expect(
            error.toString(),
            startsWith(
              "Error: The compile() method is only available in Node.js.",
            ),
          );
          return true;
        }),
      ),
    );
  });

  test('render() is not available', () {
    expect(
      () => sass.render(RenderOptions(), (error, result) {}.toJS),
      throwsA(
        predicate((error) {
          expect(error, const TypeMatcher<JSError>());
          expect(
            error.toString(),
            startsWith(
              "Error: The render() method is only available in Node.js.",
            ),
          );
          return true;
        }),
      ),
    );
  });

  test('renderSync() is not available', () {
    expect(
      () => sass.renderSync(RenderOptions()),
      throwsA(
        predicate((error) {
          expect(error, const TypeMatcher<JSError>());
          expect(
            error.toString(),
            startsWith(
              "Error: The renderSync() method is only available in Node.js.",
            ),
          );
          return true;
        }),
      ),
    );
  });

  test('info produces output', () {
    expect(sass.info, startsWith("dart-sass\t"));
  });

  test('compileString() produces output', () {
    var result = sass.compileString('foo {bar: baz}');
    expect(result.css, equals('foo {\n  bar: baz;\n}'));
  });

  test('compileString() produces a sourceMap', () {
    var opts = {'sourceMap': true}.jsify() as SyncCompileOptions;
    var result = sass.compileString('foo {bar: baz}', opts);
    expect(result.sourceMap, isA<Object>());

    var sourceMap = result.sourceMap!;

    expect(sourceMap.getProperty('version'.toJS), isA<num>());
    expect(sourceMap.getProperty('sources'.toJS), isList);
    expect(sourceMap.getProperty('names'.toJS), isList);
    expect(sourceMap.getProperty('mappings'.toJS), isA<String>());
  });

  test('compileString() produces a sourceMap with source content', () {
    var opts = {'sourceMap': true, 'sourceMapIncludeSources': true}.jsify()
        as SyncCompileOptions;
    var result = sass.compileString('foo {bar: baz}', opts);
    expect(result.sourceMap, isA<Object>());

    var sourceMap = result.sourceMap!;

    expect(sourceMap.getProperty('sourcesContent'.toJS), isList);
    expect(sourceMap.getProperty('sourcesContent'.toJS), isNotEmpty);
  });

  test('compileStringAsync() produces output', () async {
    var result = await sass.compileStringAsync('foo {bar: baz}').toDart;
    expect(result.css, equals('foo {\n  bar: baz;\n}'));
  });

  test('compileStringAsync() produces a sourceMap', () async {
    var opts = {'sourceMap': true}.jsify() as AsyncCompileOptions;
    var result = await sass.compileStringAsync('foo {bar: baz}', opts).toDart;
    var sourceMap = result.sourceMap;

    expect(sourceMap, isA<Object>());

    sourceMap = sourceMap!;

    expect(sourceMap.getProperty('version'.toJS), isA<num>());
    expect(sourceMap.getProperty('sources'.toJS), isList);
    expect(sourceMap.getProperty('names'.toJS), isList);
    expect(sourceMap.getProperty('mappings'.toJS), isA<String>());
  });

  test(
    'compileStringAsync() produces a sourceMap with source content',
    () async {
      var opts = {'sourceMap': true, 'sourceMapIncludeSources': true}.jsify()
          as AsyncCompileOptions;
      var result = await sass.compileStringAsync('foo {bar: baz}', opts).toDart;
      var sourceMap = result.sourceMap;

      expect(sourceMap, isA<Object>());

      sourceMap = sourceMap!;

      expect(sourceMap.getProperty('sourcesContent'.toJS), isList);
      expect(
        sourceMap.getProperty('sourcesContent'.toJS),
        isNotEmpty,
      );
    },
  );

  test('compileString() throws error if importing without custom importer', () {
    expect(
      () => sass.compileString("@use 'other';"),
      throwsA(
        predicate((error) {
          expect(error, const TypeMatcher<JSError>());
          expect(
            error.toString(),
            startsWith(
              "Custom importers are required to load stylesheets when compiling in the browser.",
            ),
          );
          return true;
        }),
      ),
    );
  });

  test(
    'compileStringAsync() throws error if importing without custom importer',
    () async {
      var result = sass.compileStringAsync("@use 'other';");
      expect(
        () async => await result.toDart,
        throwsA(
          predicate((error) {
            expect(error, const TypeMatcher<JSError>());
            expect(
              error.toString(),
              startsWith(
                "Custom importers are required to load stylesheets when compiling in the browser.",
              ),
            );
            return true;
          }),
        ),
      );
    },
  );
}
