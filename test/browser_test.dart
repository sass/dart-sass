@Tags(['browser'])

import 'dart:js';
import 'package:node_interop/js.dart';
import 'package:node_interop/util.dart';
import 'package:test/test.dart';

final sass = context['sass'] as JsObject;

void main() {
  test('sass object is available', () {
    expect(sass, isNotNull);
  });
  test('compileString() is available', () {
    expect(sass['compileString'], isNotNull);
  });
  test('compileStringAsync() is available', () {
    expect(sass['compileStringAsync'], isNotNull);
  });
  test('compile() is not available', () {
    expect(sass['compile'], isNull);
  });
  test('render() is not available', () {
    expect(sass['render'], isNull);
  });
  test('renderSync() is not available', () {
    expect(sass['renderSync'], isNull);
  });
  test('compileString() produces output', () {
    var result = sass.callMethod('compileString', ['foo {bar: baz}']);
    expect(result['css'], equals('foo {\n  bar: baz;\n}'));
  });
  test('compileStringAsync() produces output', () async {
    var result = sass.callMethod('compileStringAsync', ['foo {bar: baz}']);
    result = await promiseToFuture<JsObject>(result as Promise);
    expect(result['css'], equals('foo {\n  bar: baz;\n}'));
  });
}
