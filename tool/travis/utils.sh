# Copyright 2018 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# Prints the invocation of a command and then runs that command, in the same way
# Travis's internal infrastructure does.
function travis_cmd() {
  echo "\$ $@"
  "$@"
}

