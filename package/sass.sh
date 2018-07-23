#!/bin/sh
# Copyright 2016 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# This script drives the standalone Sass package, which bundles together a Dart
# executable and a snapshot of Sass. It can be created with `pub run grinder
# package`.

path="$(which "$0")"
path="$(realpath "$path")"
path="$(dirname "$path")"

exec "$path/src/dart" --no-preview-dart-2 "-Dversion=SASS_VERSION" "$path/src/sass.dart.snapshot" "$@"
