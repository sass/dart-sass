import 'package:node_interop/js.dart';

import 'compile.dart';
import 'compile_options.dart';
import 'reflection.dart';
import 'utils.dart';

class Compiler {
  bool _disposed = false;

  void throwIfDisposed() {
    if (_disposed) {
      jsThrow(JsError('Compiler has already been disposed.'));
    }
  }
}

class AsyncCompiler extends Compiler {}

/// The JS API Compiler class
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
final JSClass compilerClass = () {
  var jsClass = createJSClass('sass.Compiler', () => Compiler());

  jsClass.defineMethods({
    'compile': (Compiler self, String path, [CompileOptions? options]) {
      self.throwIfDisposed();
      return compile(path, options);
    },
    'compileString': (Compiler self, String source,
        [CompileStringOptions? options]) {
      self.throwIfDisposed();
      return compileString(source, options);
    },
    'dispose': (Compiler self) {
      self._disposed = true;
    },
  });

  getJSClass(Compiler()).injectSuperclass(jsClass);
  return jsClass;
}();

/// Returns an instance of the JS API Compiler class
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
Compiler initCompiler() => Compiler();

/// The JS AsyncCompiler class
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
final JSClass asyncCompilerClass = () {
  var jsClass = createJSClass('sass.AsyncCompiler', () => AsyncCompiler());

  jsClass.defineMethods({
    'compileAsync': (AsyncCompiler self, String path,
        [CompileOptions? options]) {
      self.throwIfDisposed();
      return compileAsync(path, options);
    },
    'compileStringAsync': (AsyncCompiler self, String source,
        [CompileStringOptions? options]) {
      self.throwIfDisposed();
      return compileStringAsync(source, options);
    },
    'dispose': (AsyncCompiler self) async {
      self._disposed = true;
    },
  });

  getJSClass(AsyncCompiler()).injectSuperclass(jsClass);
  return jsClass;
}();

/// Resolves an instance of the JS API AsyncCompiler class
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
Promise initAsyncCompiler() => futureToPromise((() async => AsyncCompiler())());
