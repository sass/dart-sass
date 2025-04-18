// Copyright 2024 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:grinder/grinder.dart';
import 'package:yaml/yaml.dart';

import 'utils.dart';

const yamlPath = 'build/language/spec/deprecations.yaml';
const dartPath = 'lib/src/deprecation.dart';

final _blockRegex = RegExp(
  r'// START AUTOGENERATED CODE[\s\S]*?// END AUTOGENERATED CODE',
);

@Task('Generate deprecation.g.dart from the list in the language repo.')
@Depends(updateLanguageRepo)
void deprecations() {
  var yamlFile = File(yamlPath);
  var yamlText = yamlFile.readAsStringSync();
  var data = loadYaml(yamlText, sourceUrl: yamlFile.uri) as Map;
  var dartText = File(dartPath).readAsStringSync();
  var buffer = StringBuffer('''// START AUTOGENERATED CODE
  //
  // DO NOT EDIT. This section was generated from the language repo.
  // See tool/grind/generate_deprecations.dart for details.
  //
  // Checksum: ${sha1.convert(utf8.encode(yamlText))}

''');
  for (var MapEntry(:String key, :value) in data.entries) {
    var camelCase = key.replaceAllMapped(
      RegExp(r'-(.)'),
      (match) => match.group(1)!.toUpperCase(),
    );
    var (description, deprecatedIn, obsoleteIn) = switch (value) {
      {'description': String description, 'dart-sass': {'status': 'future'}} =>
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
          'obsolete': String obsoleteIn,
        },
      } =>
        (description, deprecatedIn, obsoleteIn),
      _ => throw Exception('Invalid deprecation $key: $value'),
    };
    description = description.replaceAll(
      r'$PLATFORM',
      r"${isJS ? 'JS': 'Dart'}",
    );
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
      "description: '$description'),",
    );
  }
  buffer.write('\n // END AUTOGENERATED CODE');
  if (!dartText.contains(_blockRegex)) {
    fail("Couldn't find block for generated code in lib/src/deprecation.dart");
  }
  var newCode = dartText.replaceFirst(_blockRegex, buffer.toString());
  File(dartPath).writeAsStringSync(newCode);
  DartFmt.format(dartPath);
}
