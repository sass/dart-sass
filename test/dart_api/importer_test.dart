// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'package:test/test.dart';

import 'package:sass/sass.dart';
import 'package:sass/src/exception.dart';

main() {
  test("uses an importer to resolve an @import", () {
    var css = compileString('@import "orange";', importers: [
      new _TestImporter((url) => url, (url) {
        return new ImporterResult('.$url {color: $url}', indented: false);
      })
    ]);

    expect(css, equals(".orange {\n  color: orange;\n}"));
  });

  test("passes the canonicalized URL to the importer", () {
    var css = compileString('@import "orange";', importers: [
      new _TestImporter((url) => new Uri(path: 'blue'), (url) {
        return new ImporterResult('.$url {color: $url}', indented: false);
      })
    ]);

    expect(css, equals(".blue {\n  color: blue;\n}"));
  });

  test("only invokes the importer once for a given canonicalization", () {
    var css = compileString("""
      @import "orange";
      @import "orange";
    """, importers: [
      new _TestImporter(
          (url) => new Uri(path: 'blue'),
          expectAsync1((url) {
            return new ImporterResult('.$url {color: $url}', indented: false);
          }, count: 1))
    ]);

    expect(css, equals("""
.blue {
  color: blue;
}

.blue {
  color: blue;
}"""));
  });

  test("wraps an error in canonicalize()", () {
    expect(() {
      compileString('@import "orange";', importers: [
        new _TestImporter((url) {
          throw "this import is bad actually";
        }, expectAsync1((_) => null, count: 0))
      ]);
    }, throwsA(predicate((error) {
      expect(error, new isInstanceOf<SassException>());
      expect(
          error.toString(), startsWith("Error: this import is bad actually"));
      return true;
    })));
  });

  test("wraps an error in load()", () {
    expect(() {
      compileString('@import "orange";', importers: [
        new _TestImporter((url) => url, (url) {
          throw "this import is bad actually";
        })
      ]);
    }, throwsA(predicate((error) {
      expect(error, new isInstanceOf<SassException>());
      expect(
          error.toString(), startsWith("Error: this import is bad actually"));
      return true;
    })));
  });

  test("prefers .message to .toString() for an importer error", () {
    expect(() {
      compileString('@import "orange";', importers: [
        new _TestImporter((url) => url, (url) {
          throw new FormatException("bad format somehow");
        })
      ]);
    }, throwsA(predicate((error) {
      expect(error, new isInstanceOf<SassException>());
      // FormatException.toString() starts with "FormatException:", but
      // the error message should not.
      expect(error.toString(), startsWith("Error: bad format somehow"));
      return true;
    })));
  });
}

/// An [Importer] whose [canonicalize] and [load] methods are provided by
/// closures.
class _TestImporter extends Importer {
  final Uri Function(Uri url) _canonicalize;
  final ImporterResult Function(Uri url) _load;

  _TestImporter(this._canonicalize, this._load);

  Uri canonicalize(Uri url) => _canonicalize(url);

  ImporterResult load(Uri url) => _load(url);
}
