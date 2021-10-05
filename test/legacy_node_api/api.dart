// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: non_constant_identifier_names
// See dart-lang/sdk#47374

/// This library exposes Dart Sass's Node.js API, imported as JavaScript, back
/// to Dart. This is kind of convoluted, but it allows us to test the API as it
/// will be used in the real world without having to manually write any JS.

import 'package:js/js.dart';
import 'package:path/path.dart' as p;

export 'package:sass/src/node/legacy/importer_result.dart';
export 'package:sass/src/node/legacy/render_context.dart';
export 'package:sass/src/node/legacy/render_options.dart';
export 'package:sass/src/node/legacy/render_result.dart';
import 'package:sass/src/node/legacy/fiber.dart';
import 'package:sass/src/node/legacy/render_options.dart';
import 'package:sass/src/node/legacy/render_result.dart';

/// The Sass module.
final sass = _requireSass(p.absolute("build/npm/sass.dart"));

/// The Fiber class.
final fiber = _requireFiber("fibers");

/// A `null` that's guaranteed to be represented by JavaScript's `null` value,
/// not by `undefined`.
///
/// We have to use eval here because otherwise dart2js will inline the null
/// value and then optimize it away.
final Object jsNull = _eval("null");

@JS("eval")
external Object _eval(String js);

@JS("require")
external Sass _requireSass(String path);

@JS("require")
external FiberClass _requireFiber(String path);

@JS()
class Sass {
  external RenderResult renderSync(RenderOptions args);
  external void render(RenderOptions args,
      void callback(RenderError? error, RenderResult? result));
  external SassTypes get types;
  external Object get NULL;
  external NodeSassBoolean get TRUE;
  external NodeSassBoolean get FALSE;
}

@JS()
class RenderError {
  external String get message;
  external String get formatted;
  external int get line;
  external int get column;
  external String get file;
  external int get status;
}

@JS()
class SassTypes {
  external NodeSassBooleanClass get Boolean;
  external Function get Color;
  external Function get List;
  external Function get Map;
  external NodeSassNullClass get Null;
  external Function get Number;
  external Function get String;
  external Function get Error;
}

@JS()
class NodeSassBooleanClass {
  external NodeSassBoolean call();
  external NodeSassBoolean get TRUE;
  external NodeSassBoolean get FALSE;
}

@JS()
class Constructor {
  external String get name;
}

@JS()
class NodeSassBoolean {
  external Constructor get constructor;
  external bool getValue();
}

@JS()
class NodeSassColor {
  external Constructor get constructor;
  external int getR();
  external void setR(num value);
  external int getG();
  external void setG(num value);
  external int getB();
  external void setB(num value);
  external num getA();
  external void setA(num value);
}

@JS()
class NodeSassList {
  external Constructor get constructor;
  external Object getValue(int index);
  external void setValue(int index, Object value);
  external bool getSeparator();
  external void setSeparator(bool value);
  external int getLength();
}

@JS()
class NodeSassMap {
  external Constructor get constructor;
  external Object getValue(int index);
  external void setValue(int index, Object? value);
  external Object getKey(int index);
  external void setKey(int index, Object? value);
  external int getLength();
}

@JS()
class NodeSassNullClass {
  external Object call();
  external NodeSassNull get NULL;
}

@JS()
class NodeSassNull {
  external Constructor get constructor;
}

@JS()
class NodeSassNumber {
  external Constructor get constructor;
  external num getValue();
  external void setValue(int value);
  external String getUnit();
  external void setUnit(String unit);
}

@JS()
class NodeSassString {
  external Constructor get constructor;
  external String getValue();
  external void setValue(String value);
}
