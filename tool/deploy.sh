#!/bin/bash -e
# Copyright 2018 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

openssl aes-256-cbc -K $encrypted_d18df560dfb2_key -iv $encrypted_d18df560dfb2_iv \
        -in tool/encrypted/npmrc.enc -out ~/.npmrc -d
mkdir -p ~/.pub-cache
openssl aes-256-cbc -K $encrypted_d18df560dfb2_key -iv $encrypted_d18df560dfb2_iv \
        -in tool/encrypted/pub-credentials.json.enc -out ~/.pub-cache/credentials.json -d
openssl aes-256-cbc -K $encrypted_d18df560dfb2_key -iv $encrypted_d18df560dfb2_iv \
        -in tool/encrypted/git-credentials.enc -out ~/.git-credentials -d

function travis_cmd() {
  echo "\$ $@"
  "$@"
}

travis_fold() {
  local action=$1
  local name=$2
  echo -en "travis_fold:${action}:${name}\r"
}

travis_fold start npm
travis_cmd npm publish build/npm
travis_cmd npm publish build/npm-old
travis_fold end npm

travis_fold start pub
travis_cmd pub lish
travis_fold end pub

travis_fold start homebrew
git config --local user.name "Natalie Weizenbaum"
git config --local user.email "nweiz@google.com"
travis_cmd pub run grinder update-homebrew
travis_fold end homebrew
