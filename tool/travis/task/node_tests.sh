#!/bin/bash -e
# Copyright 2019 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

echo "$(tput bold)Running Node tests against Node $(node --version).$(tput sgr0)"
pub run test -j 2 -t node
