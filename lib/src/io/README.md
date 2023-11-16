# Input/Output Shim

This directory contains an API shim for doing various forms of IO across
different platforms. Dart chooses at compile time which of the three files to
use:

* `interface.dart` is used by the Dart Analyzer for static checking. It defines
  the "expected" interface of the other two files, although there aren't strong
  checks that their interfaces are exactly the same.

* `vm.dart` is used by the Dart VM, and defines IO operations in terms of the
  `dart:io` library.

* `js.dart` is used by JS platforms. On Node.js, it will use Node's `fs` and
  `process` APIs for IO operations. On other JS platforms, most IO operations
  won't work at all, although messages will still be emitted with
  `console.log()` and `console.error()`.
