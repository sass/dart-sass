These benchmarks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass da91d985 and sassc 66f0ef3 compiled with g++ (Debian 10.3.0-11) 10.3.0.
* Dart Sass bf318a8 on Dart 2.14.1 (stable) (Wed Sep 8 13:33:08 2021 +0200) on "linux_x64" and Node v16.10.0.

on Debian x64 with Intel Core i7-8650U CPU @ 1.90GHz.

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.002s
* Dart Sass from a script snapshot: 0.177s
* Dart Sass native executable: 0.009s
* Dart Sass on Node.js: 0.219s

Based on these numbers, Dart Sass from a native executable is approximately:

* 4.5x slower than libsass
* 24.3x faster than Dart Sass on Node

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 1.607s
* Dart Sass from a script snapshot: 1.643s
* Dart Sass native executable: 1.473s
* Dart Sass on Node.js: 2.529s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.7x faster than Dart Sass on Node

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`, and then `.y {a: b}`:

* sassc: 1.643s
* Dart Sass from a script snapshot: 1.723s
* Dart Sass native executable: 1.535s
* Dart Sass on Node.js: 2.574s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.7x faster than Dart Sass on Node

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`, and then `.x {@extend .y}`:

* sassc: 1.642s
* Dart Sass from a script snapshot: 1.676s
* Dart Sass native executable: 1.517s
* Dart Sass on Node.js: 2.547s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.7x faster than Dart Sass on Node

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of `.foo {a: b}`:

* sassc: 2.336s
* Dart Sass from a script snapshot: 2.453s
* Dart Sass native executable: 2.312s
* Dart Sass on Node.js: 5.874s

Based on these numbers, Dart Sass from a native executable is approximately:

* identical to libsass
* 2.5x faster than Dart Sass on Node

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by `.bar {@extend .foo}`:

* sassc: 2.353s
* Dart Sass from a script snapshot: 2.357s
* Dart Sass native executable: 2.220s
* Dart Sass on Node.js: 5.587s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 2.5x faster than Dart Sass on Node

## Bootstrap

Running on a file containing 16 instances of importing the Bootstrap framework:

* sassc: 0.789s
* Dart Sass from a script snapshot: 1.517s
* Dart Sass native executable: 0.691s
* Dart Sass on Node.js: 2.799s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 4.1x faster than Dart Sass on Node

## a11ycolor

Running on a file containing test cases for a computation-intensive color-processing library:

* sassc: 0.205s
* Dart Sass from a script snapshot: 0.649s
* Dart Sass native executable: 0.245s
* Dart Sass on Node.js: 0.827s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.2x slower than libsass
* 3.4x faster than Dart Sass on Node

## Duomo

Running on a file containing the output of the numerically-intensive Duomo framework (skipping LibSass due to module system use):

* Dart Sass from a script snapshot: 2.150s
* Dart Sass native executable: 1.406s
* Dart Sass on Node.js: 4.449s

Based on these numbers, Dart Sass from a native executable is approximately:

* 3.2x faster than Dart Sass on Node

## Carbon

Running on a file containing the output of the import-intensive Carbon framework:

* sassc: 7.481s
* Dart Sass from a script snapshot: 5.891s
* Dart Sass native executable: 5.734s
* Dart Sass on Node.js: 15.725s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.3x faster than libsass
* 2.7x faster than Dart Sass on Node

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
