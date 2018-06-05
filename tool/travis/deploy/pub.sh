#!/bin/bash -e
# Copyright 2018 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

source tool/travis/util.sh

decrypt_credentials
mkdir -p ~/.pub-cache
tar xfO credentials.tar pub > ~/.pub-cache/credentials.json

travis_cmd pub lish --force
