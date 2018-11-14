#!/bin/bash -e
# Copyright 2016 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

unformatted=`pub run dart_style:format --fix -n bin/ lib/ tool/ test/`
if [[ -z "$unformatted" ]]; then
    exit 0
else
    echo "Files are unformatted:"
    echo "$unformatted"
    exit 1
fi
