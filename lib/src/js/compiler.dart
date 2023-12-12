import 'dart:js_util';

import 'package:async/async.dart';
import 'package:node_interop/js.dart';

import 'compile.dart';
import 'compile_options.dart';
import 'reflection.dart';
import 'utils.dart';

/// The Dart Compiler class.
class Compiler {
  /// A flag signifying whether the instance has been disposed.
  bool _disposed = false;

  /// Checks if `dispose()` has been called on this instance, and throws an
  /// error if it has. Used to verify that compilation methods are not called
  /// after disposal.
  void throwIfDisposed() {
    if (_disposed) {
      jsThrow(JsError('Compiler has already been disposed.'));
    }
  }
}

/// The Dart Async Compiler class.
class AsyncCompiler extends Compiler {
  /// A set of all compilations, tracked to ensure all compilations settle
  /// before async disposal resolves.
  final FutureGroup<dynamic> compilations = FutureGroup();

  /// Adds a compilation to the FutureGroup.
  void addCompilation(Promise compilation) {
    Future<dynamic> comp = promiseToFuture(compilation);
    comp.catchError((err) {
      return;
    });
    compilations.add(comp);
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
      self.addCompilation(compilation);
      return compilation;
    },
    'compileStringAsync': (AsyncCompiler self, String source,
        [CompileStringOptions? options]) {
      self.throwIfDisposed();
      var compilation = compileStringAsync(source, options);
      self.addCompilation(compilation);
      return compilation;
    },
    'dispose': (AsyncCompiler self) {
      self._disposed = true;
      return futureToPromise((() async {
        self.compilations.close();
        await self.compilations.future;
      })());
    }
  });

  getJSClass(AsyncCompiler()).injectSuperclass(jsClass);
  return jsClass;
}();

Promise initAsyncCompiler() => futureToPromise((() async => AsyncCompiler())());
