#!/bin/bash -e
# Copyright 2019 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

echo "$(tput bold)Running Dart tests against Dart $(dart --version &> /dev/stdout).$(tput sgr0)"
pub run test -p vm -x node
