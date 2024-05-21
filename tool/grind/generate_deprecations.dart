// Copyright 2024 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_style/dart_style.dart';
import 'package:yaml/yaml.dart';

void updateDeprecationFile(File yamlFile) {
  var yamlText = yamlFile.readAsStringSync();
  var data = loadYaml(yamlText) as Map;
  var template =
      File('tool/grind/deprecation.dart.template').readAsStringSync();
  var buffer = StringBuffer();
  for (var MapEntry(:String key, :value) in data.entries) {
    var camelCase = key.replaceAllMapped(
        RegExp(r'-(.)'), (match) => match.group(1)!.toUpperCase());
    var (description, deprecatedIn, obsoleteIn) = switch (value) {
      {
        'description': String description,
        'dart-sass': {'status': 'future'},
      } =>
        (description, null, null),
      {
        'description': String description,
        'dart-sass': {'status': 'active', 'deprecated': String deprecatedIn},
      } =>
        (description, deprecatedIn, null),
      {
        'description': String description,
        'dart-sass': {
          'status': 'obsolete',
          'deprecated': String deprecatedIn,
          'obsolete': String obsoleteIn
        },
      } =>
        (description, deprecatedIn, obsoleteIn),
      _ => throw Exception('Invalid deprecation $key: $value')
    };
    description =
        description.replaceAll(r'$PLATFORM', r"${isJS ? 'JS': 'Dart'}");
    var constructorName = deprecatedIn == null ? '.future' : '';
    var deprecatedClause =
        deprecatedIn == null ? '' : "deprecatedIn: '$deprecatedIn', ";
    var obsoleteClause =
        obsoleteIn == null ? '' : "obsoleteIn: '$obsoleteIn', ";
    var comment = 'Deprecation for ${description.substring(0, 1).toLowerCase()}'
        '${description.substring(1)}';
    buffer.writeln('/// $comment');
    buffer.writeln(
        "$camelCase$constructorName('$key', $deprecatedClause$obsoleteClause"
        "description: '$description'),");
  }
  var code = template
      .replaceFirst('// REPLACE WITH AUTOGENERATED LIST', buffer.toString())
      .replaceFirst('// CHECKSUM',
          '''// DO NOT EDIT. This file was generated from the spec repo.
// See tool/grind/generate_deprecations.dart for details.
//
// Checksum: ${sha1.convert(utf8.encode(yamlText))}''');
  File('lib/src/deprecation.g.dart')
      .writeAsStringSync(DartFormatter().format(code));
}
