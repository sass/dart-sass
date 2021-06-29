#!/bin/bash -e
# Copyright 2016 Google Inc. Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# Echoes the sass-spec Git ref that should be checked out for the current GitHub
# Actions run. If we're running specs for a pull request which refers to a
# sass-spec pull request, we'll run against the latter rather than sass-spec
# main.

if [ -z "$PR_BRANCH" ]; then
  # Remove the "refs/heads/" prefix
  current_branch="${CURRENT_REF:11}"
else
  current_branch="$PR_BRANCH"
fi

if [[ "$current_branch" == feature.* ]]; then
  default="$current_branch"
else
  default=main
fi

# We don't have a PR_BRANCH so we are not in a pull request
if [ -z "$PR_BRANCH" ]; then
  >&2 echo "Ref: $default."
  echo "$default"
  exit 0
fi

>&2 echo "$PR_BODY"

RE_SPEC_PR="sass/sass-spec(#|/pull/)([0-9]+)"

if [[ "$PR_BODY" =~ $RE_SPEC_PR ]]; then
  ref="pull/${BASH_REMATCH[2]}/head"
  >&2 echo "Ref: $ref."
  echo "$ref"
else
  >&2 echo "Ref: $default."
  echo "$default"
fi
