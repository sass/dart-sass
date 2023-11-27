import 'dart:js_util';

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

class AsyncCompiler extends Compiler {
  final Set<Promise> _compilations = {};

  /// Adds a compilation to the pending set and removes it when it's done.
  void _addCompilation(Promise compilation) {
    _compilations.add(compilation);
    compilation.then((value) {
      _compilations.remove(compilation);
    }, (error) {
      _compilations.remove(compilation);
    });
  }
}

/// The JavaScript `Compiler` class.
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

Compiler initCompiler() => Compiler();

/// The JavaScript `AsyncCompiler` class.
final JSClass asyncCompilerClass = () {
  var jsClass = createJSClass('sass.AsyncCompiler', () => AsyncCompiler());

  jsClass.defineMethods({
    'compileAsync': (AsyncCompiler self, String path,
        [CompileOptions? options]) {
      self.throwIfDisposed();
      var compilation = compileAsync(path, options);
      self._addCompilation(compilation);
      return compilation;
    },
    'compileStringAsync': (AsyncCompiler self, String source,
        [CompileStringOptions? options]) {
      self.throwIfDisposed();
      var compilation = compileStringAsync(source, options);
      self._addCompilation(compilation);
      return compilation;
    },
    'dispose': (AsyncCompiler self) {
      self._disposed = true;
      return futureToPromise((() async {
        await Future.wait(self._compilations.map(promiseToFuture<Object>));
      })());
    }
  });

  getJSClass(AsyncCompiler()).injectSuperclass(jsClass);
  return jsClass;
}();

Promise initAsyncCompiler() => futureToPromise((() async => AsyncCompiler())());