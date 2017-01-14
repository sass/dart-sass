import "package:sass/sass.dart";
import 'package:sass/src/exception.dart';
import "package:sass/src/sync_package_resolver/sync_package_resolver.dart";
import "package:scheduled_test/descriptor.dart" as d;
import "package:scheduled_test/scheduled_test.dart";
import "utils.dart";

main() {
  useSandbox();

  test("success to import package uri", () async {
    await d.file("test_aux.scss", "a {b: 1 + 2}").create();
    await d
        .file("test.scss", "@import \"package:fake_package/test_aux\";")
        .create();
    var packageResolver =
        new SyncPackageResolver.config({"fake_package": new Uri.file(sandbox)});
    var css = render(sandbox + "/test.scss", packageResolver: packageResolver);
    expect(
        css,
        "a {\n"
        "  b: 3;\n"
        "}");
  });

  test("fails to import package uri", () async {
    await d.file("test_aux.scss", "a {b: 1 + 2}").create();
    await d
        .file("test.scss", "@import \"package:fake_package/test_aux\";")
        .create();
    var packageResolver = new SyncPackageResolver.config({});
    expect(
        () => render(sandbox + "/test.scss", packageResolver: packageResolver),
        throwsA(new isInstanceOf<SassRuntimeException>()));
  });
}
