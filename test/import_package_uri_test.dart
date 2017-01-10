import 'package:sass/src/exception.dart';
import 'package:test/test.dart';
import 'package:sass/sass.dart';

main() {
  group('import "package:" uri', () {
    test('found', () async {
      var result = await render('test/styles/import-package.scss');
      expect(result, '');
    });
    test('not found', () async {
      try {
        await render('test/styles/import-package-not-found.scss');
      } catch (e) {
        expect(e.runtimeType, SassRuntimeException);
        expect(
            e.toString(),
            '''Error on line 1, column 9 of test/styles/import-package-not-found.scss: Can\'t find file to import.
@import 'package:non_exising/scss';
        ^^^^^^^^^^^^^^^^^^^^^^^^^^
  test/styles/import-package-not-found.scss 1:9  root stylesheet''');
        return;
      }
      throw new Exception("Expected ArgumentError");
    });
  });
}
