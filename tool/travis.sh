#!/bin/bash -e
# Copyright 2017 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

bold=$(tput bold)
none=$(tput sgr0)

if [ "$TRAVIS_OS_NAME" = "osx"]; then
  # Run all tests as once on OS X since the builder backlog is so large.
  pub run test
  cd sass-spec
  exec bundle exec sass-spec.rb --dart ..
else
  if [ "$TASK" = analyze ]; then
    echo "${bold}Analzing Dart code.$none"
    exec dartanalyzer --fatal-warnings lib/ test/ tool/
  elif [ "$TASK" = format ]; then
    echo "${bold}Ensuring Dart code is formatted.$none"
    exec ./tool/assert-formatted.sh
  elif [ "$TASK" = tests ]; then
    if [ -z "$NODE_VERSION" ]; then
      echo "${bold}Running Dart tests against $(dart --version &> /dev/stdout).$none"
      exec pub run test -x node
    else
      echo "${bold}Running Node tests against Node $(node --version).$none"
      exec pub run test -t node
    fi
  else
    echo "${bold}Running sass-spec against $(dart --version &> /dev/stdout).$none"
    cd sass-spec
    exec bundle exec sass-spec.rb --dart ..
  fi
fi
