# Copyright 2018 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# Decrypts the encrypted credentials using Travis's private key and saves them
# to credentials.tar.
function decrypt_credentials() {
    openssl aes-256-cbc -K $encrypted_b4541d8c554c_key \
            -iv $encrypted_b4541d8c554c_iv \
            -in tool/travis/credentials.tar.enc \
            -out credentials.tar -d
}

# Prints the invocation of a command and then runs that command, in the same way
# Travis's internal infrastructure does.
function travis_cmd() {
  echo "\$ $@"
  "$@"
}

