#!/bin/bash -e
# Copyright 2019 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# A script that installs Dart and runs "pub get" if the current worker isn't
# using Travis's Dart support.

if [ ! -z "$TRAVIS_DART_VERSION" ]; then exit 0; fi

echo "$(tput bold)Installing Dart $DART_CHANNEL/$DART_VERSION.$(tput sgr0)"

source tool/travis/utils.sh

os="$TRAVIS_OS_NAME"
if [ "$os" = osx ]; then os=macos; fi
travis_cmd curl -o dart.zip "https://storage.googleapis.com/dart-archive/channels/$DART_CHANNEL/release/$DART_VERSION/sdk/dartsdk-$os-x64-release.zip"
travis_cmd unzip dart.zip

export PATH="$PATH:`pwd`/dart-sdk/bin";
if [ "$os" = windows ]; then echo 'pub.bat "$@"' > `pwd`/dart-sdk/bin/pub; fi
if [ "$os" = windows ]; then chmod a+x `pwd`/dart-sdk/bin/pub; fi

travis_cmd `pwd`/dart-sdk/bin/pub get
