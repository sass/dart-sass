#!/bin/bash -e
# Copyright 2019 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

echo "$(tput bold)Running sass-spec against $(dart --version &> /dev/stdout).$(tput sgr0)"
if [ "$ASYNC" = true ]; then extra_args="--cmd-args --async"; fi
(cd sass-spec; bundle exec sass-spec.rb --dart .. $extra_args)
