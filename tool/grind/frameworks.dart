// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';

import 'package:grinder/grinder.dart';
import 'package:http/http.dart' as http;

import 'utils.dart';

@Task('Download Bootstrap 5.x for testing purposes.')
Future<void> fetchBootstrap5() => _getLatestRelease('twbs/bootstrap');

@Task('Download Bootstrap 4.x for testing purposes.')
Future<void> fetchBootstrap4() =>
    _getLatestRelease('twbs/bootstrap', pattern: RegExp(r'^v4\.'));

@Task('Download Bourbon for testing purposes.')
Future<void> fetchBourbon() => _getLatestRelease('thoughtbot/bourbon');

@Task('Download Foundation for testing purposes.')
Future<void> fetchFoundation() =>
    _getLatestRelease('foundation/foundation-sites');

@Task('Download Bulma for testing purposes.')
Future<void> fetchBulma() => _getLatestRelease('jgthms/bulma');

/// Clones the latest release of the given GitHub repository [slug].
///
/// If [pattern] is passed, this will clone the latest release that matches that
/// pattern.
Future<void> _getLatestRelease(String slug, {Pattern? pattern}) async {
  await cloneOrCheckout('git://github.com/$slug',
      await _findLatestRelease(slug, pattern: pattern));
}

/// Returns the tag name of the latest release for the given GitHub repository
/// [slug].
///
/// If [pattern] is passed, this will find the latest release that matches that
/// pattern.
Future<String> _findLatestRelease(String slug, {Pattern? pattern}) async {
  var releases = await _fetchReleases(slug);
  if (pattern == null) return releases[0]['tag_name'] as String;

  var page = 1;
  while (releases.isNotEmpty) {
    for (var release in releases) {
      var tagName = release['tag_name'] as String;
      if (pattern.allMatches(tagName).isNotEmpty) return tagName;
    }

    page++;
    releases = await _fetchReleases(slug, page: page);
  }

  fail("Couldn't find a release of $slug matching $pattern.");
}

/// Fetches the GitHub releases page for the repo at [slug].
Future<List<Map<String, dynamic>>> _fetchReleases(String slug,
    {int page = 1}) async {
  var result = json.decode(await http.read(
      Uri.parse("https://api.github.com/repos/$slug/releases?page=$page"),
      headers: {
        "accept": "application/vnd.github.v3+json",
        "authorization": githubAuthorization
      })) as List<dynamic>;
  return result.cast<Map<String, dynamic>>();
}
