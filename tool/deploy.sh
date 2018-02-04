#!/bin/bash -e
# Copyright 2018 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

openssl aes-256-cbc -K $encrypted_d18df560dfb2_key -iv $encrypted_d18df560dfb2_iv \
        -in tool/encrypted/npmrc.enc -out ~/.npmrc -d
npm publish build/npm
npm publish build/npm-old

mkdir -p ~/.pub-cache
openssl aes-256-cbc -K $encrypted_d18df560dfb2_key -iv $encrypted_d18df560dfb2_iv \
        -in tool/encrypted/pub-credentials.json.enc -out ~/.pub-cache/credentials.json -d
pub lish

openssl aes-256-cbc -K $encrypted_d18df560dfb2_key -iv $encrypted_d18df560dfb2_iv \
        -in tool/encrypted/git-credentials.enc -out ~/.git-credentials -d
git config --local user.name "Natalie Weizenbaum"
git config --local user.email "nweiz@google.com"
pub run grinder update-homebrew
