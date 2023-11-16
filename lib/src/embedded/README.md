# Embedded Sass Compiler

This directory contains the Dart Sass embedded compiler. This is a special mode
of the Dart Sass command-line executable, only supported on the Dart VM, in
which it uses stdin and stdout to communicate with another endpoint, the
"embedded host", using a protocol buffer-based protocol. See [the embedded
protocol specification] for details.

[the embedded protocol specification]: https://github.com/sass/sass/blob/main/spec/embedded-protocol.md

The embedded compiler has two different levels of dispatchers for handling
incoming messages from the embedded host:

1. The [`IsolateDispatcher`] is the first recipient of each packet. It decodes
   the packets _just enough_ to determine which compilation they belong to, and
   forwards them to the appropriate compilation dispatcher. It also parses and
   handles messages that aren't compilation specific, such as `VersionRequest`.

   [`IsolateDispatcher`]: isolate_dispatcher.dart

2. The [`CompilationDispatcher`] fully parses and handles messages for a single
   compilation. Each `CompilationDispatcher` runs in a separate isolate so that
   the embedded compiler can run multiple compilations in parallel.

   [`CompilationDispatcher`]: compilation_dispatcher.dart

Otherwise, most of the code in this directory just wraps Dart APIs to
communicate with their protocol buffer equivalents.
