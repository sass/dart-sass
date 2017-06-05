// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'src/exception.dart';
import 'src/render.dart' as r;
import 'src/sync_package_resolver.dart';
import 'src/visitor/serialize.dart';

/// Loads the Sass file at [path], converts it to CSS, and returns the result.
///
/// If [color] is `true`, this will use terminal colors in warnings.
///
/// If [packageResolver] is provided, it's used to resolve `package:` imports.
/// Otherwise, they aren't supported. It takes a [SyncPackageResolver][] from
/// the `package_resolver` package.
///
/// [SyncPackageResolver]: https://www.dartdocs.org/documentation/package_resolver/latest/package_resolver/SyncPackageResolver-class.html
///
/// Finally throws a [SassException] if conversion fails.
String render(String path,
        {bool color: false,
        SyncPackageResolver packageResolver,
        LineFeed linefeed: LineFeed.LF}) =>
    r.render(path, color: color, packageResolver: packageResolver, linefeed:
        linefeed);
