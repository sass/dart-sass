#!/bin/bash -e
# Copyright 2018 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

bold=$(tput bold)
none=$(tput sgr0)

if [ "$TASK" = analyze ]; then
  echo "${bold}Analzing Dart code.$none"
  dartanalyzer --fatal-warnings lib/ test/ tool/
elif [ "$TASK" = format ]; then
  echo "${bold}Ensuring Dart code is formatted.$none"
  ./tool/assert-formatted.sh
elif [ "$TASK" = tests ]; then
  if [ -z "$TRAVIS_NODE_VERSION" ]; then
    echo "${bold}Running Dart tests against $(dart --version &> /dev/stdout).$none"
    pub run test -p vm -x node
  else
    echo "${bold}Running Node tests against Node $(node --version).$none"
    pub run test -j 2 -t node
  fi;
else
  echo "${bold}Running sass-spec against $(dart --version &> /dev/stdout).$none"
  if [ "$ASYNC" = true ]; then
    extra_args="--dart-args --async"
  fi;
  (cd sass-spec; bundle exec sass-spec.rb --dart .. $extra_args)
fi
