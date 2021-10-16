These benchmarks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass da91d985 and sassc 66f0ef3 compiled with g++ (Debian 10.3.0-11) 10.3.0.
* Dart Sass 7934ad9 on Dart 2.14.1 (stable) (Wed Sep 8 13:33:08 2021 +0200) on "linux_x64" and Node v16.10.0.

on Debian x64 with Intel Core i7-8650U CPU @ 1.90GHz.

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.003s
* Dart Sass from a script snapshot: 0.191s
* Dart Sass native executable: 0.009s
* Dart Sass on Node.js: 0.224s

Based on these numbers, Dart Sass from a native executable is approximately:

* 3.0x slower than libsass
* 24.9x faster than Dart Sass on Node

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 1.612s
* Dart Sass from a script snapshot: 1.663s
* Dart Sass native executable: 1.485s
* Dart Sass on Node.js: 2.583s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.7x faster than Dart Sass on Node

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`, and then `.y {a: b}`:

* sassc: 1.644s
* Dart Sass from a script snapshot: 1.721s
* Dart Sass native executable: 1.506s
* Dart Sass on Node.js: 2.613s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.7x faster than Dart Sass on Node

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`, and then `.x {@extend .y}`:

* sassc: 1.643s
* Dart Sass from a script snapshot: 1.655s
* Dart Sass native executable: 1.504s
* Dart Sass on Node.js: 2.625s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.7x faster than Dart Sass on Node

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of `.foo {a: b}`:

* sassc: 2.331s
* Dart Sass from a script snapshot: 2.433s
* Dart Sass native executable: 2.264s
* Dart Sass on Node.js: 5.822s

Based on these numbers, Dart Sass from a native executable is approximately:

* identical to libsass
* 2.6x faster than Dart Sass on Node

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by `.bar {@extend .foo}`:

* sassc: 2.367s
* Dart Sass from a script snapshot: 2.367s
* Dart Sass native executable: 2.189s
* Dart Sass on Node.js: 5.612s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 2.6x faster than Dart Sass on Node

## Bootstrap

Running on a file containing 16 instances of importing the Bootstrap framework:

* sassc: 0.791s
* Dart Sass from a script snapshot: 1.707s
* Dart Sass native executable: 0.778s
* Dart Sass on Node.js: 3.101s

Based on these numbers, Dart Sass from a native executable is approximately:

* identical to libsass
* 4.0x faster than Dart Sass on Node

## a11ycolor

Running on a file containing test cases for a computation-intensive color-processing library:

* sassc: 0.207s
* Dart Sass from a script snapshot: 0.700s
* Dart Sass native executable: 0.267s
* Dart Sass on Node.js: 0.953s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.3x slower than libsass
* 3.6x faster than Dart Sass on Node

## Duomo

Running on a file containing the output of the numerically-intensive Duomo framework (skipping LibSass due to module system use):

* Dart Sass from a script snapshot: 2.298s
* Dart Sass native executable: 1.361s
* Dart Sass on Node.js: 4.659s

Based on these numbers, Dart Sass from a native executable is approximately:

* 3.4x faster than Dart Sass on Node

## Carbon

Running on a file containing the output of the import-intensive Carbon framework:

* sassc: 6.576s
* Dart Sass from a script snapshot: 9.662s
* Dart Sass native executable: 9.874s
* Dart Sass on Node.js: 25.425s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.5x slower than libsass
* 2.6x faster than Dart Sass on Node

# Prior Measurements

* [1.22.6](https://github.com/sass/dart-sass/blob/eec6ccc9d96fdb5dd30122a0c824efe8a6bfd168/perf.md).
* [1.22.5](https://github.com/sass/dart-sass/blob/ed73c2c053435703cfbee8709f0dfb110cd31487/perf.md).
* [1.22.4](https://github.com/sass/dart-sass/blob/a7172a2b1dd48b339e5d57159ed364ffb9f5812e/perf.md).
* [1.20.2](https://github.com/sass/dart-sass/blob/4b7699291c9f69533d25980d23b0647266b665f2/perf.md).
* [1.13.4](https://github.com/sass/dart-sass/blob/b6ccc91a138e75420227ff79381c5f70e60254f1/perf.md).
* [1.6.0](https://github.com/sass/dart-sass/blob/048cbe197a77e1cf4b837a40a5acb737e949fd5c/perf.md).
* [1.0.0-alpha.8](https://github.com/sass/dart-sass/blob/be44245a849f2bb18b5ca1fc74f3043a36da17f0/perf.md).
* [Pre-alpha, 30 September 2016](https://github.com/sass/dart-sass/blob/169370bf18fd01d0618b0fc00d9db33e2fc52aa7/perf.md).
* [Pre-alpha, 19 August 2016](https://github.com/sass/dart-sass/blob/4bea13cfe57d9e3c7f1f8580b80c59abe1cfabf8/perf.md).
* [Pre-alpha, 15 July 2016](https://github.com/sass/dart-sass/blob/a3e00059c4371bfde9afada1759d8484aee05584/perf.md).

# Conclusions

This is the first measurement with Dart Sass running as ahead-of-time-compiled
native code, and the results are encouraging. It's well below the 100ms
threshold for tiny files, and it's on par with SassC for most test cases. SassC
still leads for tests with many extends, although only slightly, and for one of
our real-world test cases (although Dart Sass leads in others). The two
implementations can be fairly described as having about the same performance
overall.

Dart Sass on Node is still substantially slower than on the Dart VM, and that
relative slowdown becomes more pronounced as the raw Dart code becomes faster.
Solutions for this such as [the embedded protocol][] or [WebAssembly support][]
are becoming more and more important.

[the embedded protocol]: https://github.com/sass/sass-embedded-protocol
[WebAssembly support]: https://github.com/dart-lang/sdk/issues/32894
