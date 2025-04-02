# Embedded Sass Compiler

This directory contains the Dart Sass embedded compiler. This is a special mode
of the Dart Sass command-line executable, only supported on the Dart VM and
Node.js, in which it uses stdin and stdout to communicate with another endpoint,
the "embedded host", using a protocol buffer-based protocol. See [the embedded
protocol specification] for details.

[the embedded protocol specification]: https://github.com/sass/sass/blob/main/spec/embedded-protocol.md

The embedded compiler has two different levels of dispatchers for handling
incoming messages from the embedded host:

1. The [`WorkerDispatcher`] is the first recipient of each packet. It decodes
   the packets _just enough_ to determine which compilation they belong to, and
   forwards them to the appropriate compilation dispatcher. It also parses and
   handles messages that aren't compilation specific, such as `VersionRequest`.

   [`WorkerDispatcher`]: worker_dispatcher.dart

2. The [`CompilationDispatcher`] fully parses and handles messages for a single
   compilation. Each `CompilationDispatcher` runs in a separate worker so that
   the embedded compiler can run multiple compilations in parallel.

   [`CompilationDispatcher`]: compilation_dispatcher.dart

Otherwise, most of the code in this directory just wraps Dart APIs or JS APIs to
communicate with their protocol buffer equivalents.

## Worker Communication and Management

The way Dart VM launches lightweight isolates versus Node.js launches worker
threads are very different.

In Dart VM, the lightweight isolates share program structures like loaded
libraries, classes, functions, etc., even including JIT optimized code. This
allows main isolate to spawn child isolate with a reference to the entry point
function.

```
┌─────────────────┐                                                    ┌─────────────────┐
│ Main Isolate    │ Isolate.spawn(workerEntryPoint, mailbox, sendPort) │ Worker Isolate  │
│                 ├───────────────────────────────────────────────────►│                 │
│                 │                                                    │                 │
│ ┌─────────────┐ │               Synchronous Messaging                │ ┌─────────────┐ │
│ │ Mailbox     ├─┼────────────────────────────────────────────────────┼►│ Mailbox     │ │
│ └─────────────┘ │                                                    │ └─────────────┘ │
│                 │                                                    │                 │
│ ┌─────────────┐ │               Asynchronous Messaging               │ ┌─────────────┐ │
│ │ ReceivePort │◄┼────────────────────────────────────────────────────┼─┤ SendPort    │ │
│ └─────────────┘ │                                                    │ └─────────────┘ │
│                 │                                                    │                 │
└─────────────────┘                                                    └─────────────────┘
```

In Node.JS, the worker threads do not share program structures. In order to
launch a worker thread, it needs an entry point file, with the entry point
function effectly hard-coded in the entry point file. While it's possible
to have a separate entry point file for the worker threads, it requires more
complex packaging changes with `cli_pkg`, therefore the main thread and the
worker threads share [the same entry point file](js/executable.dart), which
decides what to run based on `worker_threads.isMainThread`.

```
  if (worker_threads.isMainThread) {                                                                 if (worker_threads.isMainThread) {
    mainEntryPoint();                                                                                  mainEntryPoint();
  } else {                                                                                           } else {
    workerEntryPoint();                new Worker(process.argv[1], {                                   workerEntryPoint();
  }                                                                  argv: process.argv.slice(2),    }
                                                                     workerData: channel.port2,
┌────────────────────────────────────┐                               transferList: [channel.port2] ┌────────────────────────────────────┐
│ Main Thread                        │                             })                              │ Worker Thread                      │
│                                    ├────────────────────────────────────────────────────────────►│                                    │
│                                    │                                                             │                                    │
│ ┌────────────────────────────────┐ │               Synchronous Messaging                         │ ┌────────────────────────────────┐ │
│ │ SyncMessagePort(channel.port1) ├─┼─────────────────────────────────────────────────────────────┼►│ SyncMessagePort(channel.port2) │ │
│ └────────────────────────────────┘ │                                                             │ └────────────────────────────────┘ │
│                                    │                                                             │                                    │
│ ┌────────────────────────────────┐ │               Asynchronous Messaging                        │ ┌────────────────────────────────┐ │
│ │ channel.port1                  │◄┼─────────────────────────────────────────────────────────────┼─┤ channel.port2                  │ │
│ └────────────────────────────────┘ │                                                             │ └────────────────────────────────┘ │
│                                    │                                                             │                                    │
└────────────────────────────────────┘                                                             └────────────────────────────────────┘
```
