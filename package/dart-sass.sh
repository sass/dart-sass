#!/bin/sh
# Copyright 2016 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# This script drives the standalone Sass package, which bundles together a Dart
# executable and a snapshot of Sass. It can be created with `pub run grinder
# package`.

follow_links() {
  file="$1"
  while [ -h "$file" ]; do
    # On Mac OS, readlink -f doesn't work.
    file="$(readlink "$file")"
  done
  echo "$file"
}

if [ -t 1 ]; then
  echo -e "\e[1;33mWarning\e[0;0m: The \e[1;1mdart-sass\e[0;0m executable is deprecated, use \e[1;1msass\e[0;0m instead."
fi

# Unlike $0, $BASH_SOURCE points to the absolute path of this file.
path=`dirname "$(follow_links "$BASH_SOURCE")"`
exec "$path/src/dart" "$path/src/sass.dart.snapshot" "$@"
