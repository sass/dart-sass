// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:grinder/grinder.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

import 'standalone.dart';
import 'utils.dart';

@Task('Build a Chocolatey package.')
@Depends(snapshot)
void chocolateyPackage() {
  ensureBuild();

  var nuspec = _nuspec();
  var archive = Archive()
    ..addFile(fileFromString("sass.nuspec", nuspec.toString()))
    ..addFile(
        file("[Content_Types].xml", "package/chocolatey/[Content_Types].xml"))
    ..addFile(file("_rels/.rels", "package/chocolatey/rels.xml"))
    ..addFile(fileFromString(
        "package/services/metadata/core-properties/properties.psmdcp",
        _nupkgProperties(nuspec)))
    ..addFile(file("tools/LICENSE", "LICENSE"))
    ..addFile(file("tools/sass.dart.snapshot", "build/sass.dart.snapshot"))
    ..addFile(file("tools/chocolateyInstall.ps1",
        "package/chocolatey/chocolateyInstall.ps1"))
    ..addFile(file("tools/chocolateyUninstall.ps1",
        "package/chocolatey/chocolateyUninstall.ps1"))
    ..addFile(file("tools/sass.bat", "package/chocolatey/sass.bat"));

  var output = "build/sass.${_chocolateyVersion()}.nupkg";
  log("Creating $output...");
  File(output).writeAsBytesSync(ZipEncoder().encode(archive));
}

/// Creates a `sass.nuspec` file's contents.
xml.XmlDocument _nuspec() {
  String sdkVersion;
  if (isDevSdk) {
    assert(dartVersion.preRelease[0] == "dev");
    assert(dartVersion.preRelease[1] is int);
    sdkVersion = "${dartVersion.major}.${dartVersion.minor}."
        "${dartVersion.patch}.${dartVersion.preRelease[1]}-dev-"
        "${dartVersion.preRelease[2]}";
  } else {
    sdkVersion = dartVersion.toString();
  }

  var builder = xml.XmlBuilder();
  builder.processing("xml", 'version="1.0"');
  builder.element("package", nest: () {
    builder
        .namespace("http://schemas.microsoft.com/packaging/2011/10/nuspec.xsd");
    builder.element("metadata", nest: () {
      builder.element("id", nest: "sass");
      builder.element("title", nest: "Sass");
      builder.element("version", nest: _chocolateyVersion());
      builder.element("authors", nest: "Natalie Weizenbaum");
      builder.element("owners", nest: "nex3");
      builder.element("projectUrl", nest: "https://github.com/sass/dart-sass");
      builder.element("licenseUrl",
          nest: "https://github.com/sass/dart-sass/blob/$version/LICENSE");
      builder.element("iconUrl",
          nest: "https://cdn.rawgit.com/sass/sass-site/"
              "f99ee33e4f688e244c7a5902c59d61f78daccc55/source/assets/img/"
              "logos/logo-seal.png");
      builder.element("bugTrackerUrl",
          nest: "https://github.com/sass/dart-sass/issues");
      builder.element("description", nest: """
**Sass makes CSS fun again**. Sass is an extension of CSS, adding nested rules, variables, mixins, selector inheritance, and more. It's translated to well-formatted, standard CSS using the command line tool or a web-framework plugin.

This package is Dart Sass, the new Dart implementation of Sass.
""");
      builder.element("summary", nest: "Sass makes CSS fun again.");
      builder.element("tags", nest: "css preprocessor style sass");
      builder.element("copyright",
          nest: "Copyright ${DateTime.now().year} Google, Inc.");
      builder.element("dependencies", nest: () {
        builder.element("dependency", attributes: {
          "id": "dart-sdk",
          // Unfortunately we need the exact same Dart version as we built with,
          // since we ship a snapshot which isn't cross-version compatible. Once
          // we switch to native compilation this won't be an issue.
          "version": "[$sdkVersion]",
        });
      });
    });
  });

  return builder.build() as xml.XmlDocument;
}

@Task('Upload the Chocolatey package to the current version.')
@Depends(chocolateyPackage)
Future<void> updateChocolatey() async {
  // For some reason, although Chrome seems able to access it just fine,
  // command-line tools don't seem to be able to verify the certificate for
  // Chocolatey, so we need to manually add the intermediate GoDaddy certificate
  // to the security context.
  SecurityContext.defaultContext.setTrustedCertificates("tool/godaddy.pem");

  var request = http.MultipartRequest(
      "PUT", Uri.parse("https://chocolatey.org/api/v2/package"));
  request.headers["X-NuGet-Protocol-Version"] = "4.1.0";
  request.headers["X-NuGet-ApiKey"] = environment("CHOCO_TOKEN");
  request.files.add(await http.MultipartFile.fromPath(
      "package", "build/sass.${_chocolateyVersion()}.nupkg"));

  var response = await request.send();
  if (response.statusCode ~/ 100 != 2) {
    fail("${response.statusCode} error creating release:\n"
        "${await response.stream.bytesToString()}");
  } else {
    log("Released Dart Sass ${_chocolateyVersion()} to Chocolatey.");
    response.stream.listen(null).cancel();
  }
}

/// The current Sass version, formatted for Chocolatey which doesn't allow dots
/// in prerelease versions.
String _chocolateyVersion() {
  var components = version.split("-");
  if (components.length == 1) return components.first;
  assert(components.length == 2);

  var first = true;
  var prerelease = components.last.replaceAllMapped('.', (_) {
    if (first) {
      first = false;
      return '';
    } else {
      return '-';
    }
  });
  return "${components.first}-$prerelease";
}

/// Returns the contents of the `properties.psmdcp` file, computed from the
/// nuspec's XML.
String _nupkgProperties(xml.XmlDocument nuspec) {
  var builder = xml.XmlBuilder();
  builder.processing("xml", 'version="1.0"');
  builder.element("coreProperties", nest: () {
    builder.namespace(
        "http://schemas.openxmlformats.org/package/2006/metadata/core-properties");
    builder.namespace("http://purl.org/dc/elements/1.1/", "dc");
    builder.element("dc:creator",
        nest: nuspec.findAllElements("authors").first.text);
    builder.element("dc:description",
        nest: nuspec.findAllElements("description").first.text);
    builder.element("dc:identifier",
        nest: nuspec.findAllElements("id").first.text);
    builder.element("version",
        nest: nuspec.findAllElements("version").first.text);
    builder.element("keywords",
        nest: nuspec.findAllElements("tags").first.text);
    builder.element("dc:title",
        nest: nuspec.findAllElements("title").first.text);
  });
  return builder.build().toString();
}
