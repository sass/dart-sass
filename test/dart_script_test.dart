// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_test.dart';

import 'package:sass/sass.dart';
import 'package:sass/src/exception.dart';

import 'utils.dart';

main() {
  useSandbox();

  test("successfully imports a package URL", () {
    d.dir("subdir", [d.file("test.scss", "a {b: 1 + 2}")]).create();

    d.file("test.scss", '@import "package:fake_package/test";').create();
    var resolver = new SyncPackageResolver.config(
        {"fake_package": p.toUri(p.join(sandbox, 'subdir'))});

    schedule(() {
      var css = render(path: p.join(sandbox, "test.scss"), packageResolver: resolver);
      expect(css, equals("a {\n  b: 3;\n}"));
    });
  });

  test("imports a package URL from a missing package", () {
    d.file("test.scss", '@import "package:fake_package/test_aux";').create();
    var resolver = new SyncPackageResolver.config({});

    schedule(() {
      expect(() => render(path: sandbox + "/test.scss", packageResolver: resolver),
          throwsA(new isInstanceOf<SassRuntimeException>()));
    });
  });
}
