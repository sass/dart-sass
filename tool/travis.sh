#!/bin/bash -e
# Copyright 2016 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# Echoes a command, then runs it.
echo-and-run ()
{
    echo "\$ $@"
    "$@"
}

# Emit folding annotations on Travis, or just newlines elsewhere.
fold ()
{
    if [ "$TRAVIS" = true ]; then
        echo "travis_fold:start:$1"
    fi
    echo-and-run "${@:2}"
    if [ "$TRAVIS" = true ]; then
        echo "travis_fold:end:$1"
    else
        echo
        echo
    fi
}

if [ "$ANALYZE" != false ]; then
    echo-and-run dartanalyzer --fatal-warnings lib/
fi
echo-and-run ./tool/assert-formatted.sh

dart_sass=`pwd`
dir=`mktemp -d /tmp/sass-spec-XXXXXXXX`
cd "$dir"

fold "git.sass-spec" \
     git clone git://github.com/sass/sass-spec --branch dart-sass --depth 1
cd sass-spec

fold "bundle" bundle install --jobs=3 --retry=3
echo-and-run bundle exec sass-spec.rb --output-style expanded --probe-todo --dart "$dart_sass"
