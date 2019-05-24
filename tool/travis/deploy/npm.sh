#!/bin/bash -e
# Copyright 2018 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

echo 'Deploying to npm.'

source tool/travis/utils.sh

echo "$NPM_RC" > ~/.npmrc

travis_cmd pub run grinder npm-release-package
travis_cmd npm publish build/npm
travis_cmd npm publish build/npm-old
