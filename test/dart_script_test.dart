// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:sass/sass.dart';
import 'package:sass/src/exception.dart';

main() {
  test("successfully imports a package URL", () async {
    await d.dir("subdir", [d.file("test.scss", "a {b: 1 + 2}")]).create();

    await d.file("test.scss", '@import "package:fake_package/test";').create();
    var resolver = new SyncPackageResolver.config(
        {"fake_package": p.toUri(p.join(d.sandbox, 'subdir'))});

    var css = render(p.join(d.sandbox, "test.scss"), packageResolver: resolver);
    expect(css, equals("a {\n  b: 3;\n}"));
  });

  test("imports a package URL from a missing package", () async {
    await d
        .file("test.scss", '@import "package:fake_package/test_aux";')
        .create();
    var resolver = new SyncPackageResolver.config({});

    expect(() => render(d.sandbox + "/test.scss", packageResolver: resolver),
        throwsA(new isInstanceOf<SassRuntimeException>()));
  });
}
