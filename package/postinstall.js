// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ============================== Configuration ============================= //

// The date the announcement was published on.
const publicationDate = Date.parse('2021-03-15T12:00-07:00');

// The number of weeks after `publicationDate` during which the announcement
// will be printed.
const durationInWeeks = 4;

// The message to print about the latest request for comments.
const message = `
## Request for Comments: First-Class Calc ##

https://sass-lang.com/blog/request-for-comments-first-class-calc

We want your feedback on the latest Sass language proposal! First-class calc
will allow users to write Sass variables in calc()s, combine multiple calc()s,
and resolve certain calc()s at compile time.
`.trim();

// ========================================================================== //

const fs = require('fs');
const os = require('os');
const p = require('path');

const msInHour = 60 * 60 * 1000;
const msInWeek = 7 * 24 * msInHour;

// Don't print messages when running in CI environments.
if ((process.env.CI && process.env.CI !== 'false') ||
    // Don't print messages if the user sets ADBLOCK=true. This isn't really an
    // ad, but this is an accepted way to silence postinstall messages.
    (process.env.ADBLOCK && process.env.ADBLOCK !== 'false') ||
    // Respect npm's loglevel configuration.
    ['silent', 'error', 'warn'].includes(process.env.npm_config_loglevel) ||
    // Don't print the message once `durationInWeeks` has expired. At this
    // point, the proposal will probably have been accepted.
    Date.now() - publicationDate > msInWeek * durationInWeeks) {
  process.exit(0);
}

// Check the mtime of a sentinel file to avoid annoying users by printing a
// message more than once an hour.
try {
  const sentinelPath = p.join(os.tmpdir(), 'dart-sass-postinstall-run');
  try {
    var timeSinceLastRun = Date.now() - fs.statSync(sentinelPath).mtime;
    if (timeSinceLastRun > 0 && timeSinceLastRun < msInHour) process.exit(0);
  } catch (_) {
    // fs.statSync is expected to error if sentinelPath doesn't exist yet.
  }

  fs.writeFileSync(sentinelPath, '');
} catch (_) {
  // This may error, for example because we don't have filesystem read/write
  // permissions. That's fine; in that case, we just print the message anyway.
  throw _;
}

console.log(message);
