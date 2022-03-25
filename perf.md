These benchmarks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass 006bbf5 and sassc 66f0ef3 compiled with g++ (Debian 11.2.0-10) 11.2.0.
* Dart Sass 4fa365a on Dart 2.15.0 (stable) (Fri Dec 3 14:23:23 2021 +0100) on "linux_x64" and Node v16.10.0.

on Debian x64 with Intel Core i7-8650U CPU @ 1.90GHz.

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.003s
* Dart Sass from a script snapshot: 0.327s
* Dart Sass native executable: 0.011s
* Dart Sass on Node.js: 0.281s

Based on these numbers, Dart Sass from a native executable is approximately:

* 3.7x slower than libsass
* 25.5x faster than Dart Sass on Node

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 1.769s
* Dart Sass from a script snapshot: 2.061s
* Dart Sass native executable: 1.666s
* Dart Sass on Node.js: 3.913s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 2.3x faster than Dart Sass on Node

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`, and then `.y {a: b}`:

* sassc: 1.846s
* Dart Sass from a script snapshot: 2.218s
* Dart Sass native executable: 1.726s
* Dart Sass on Node.js: 4.176s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 2.4x faster than Dart Sass on Node

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`, and then `.x {@extend .y}`:

* sassc: 1.778s
* Dart Sass from a script snapshot: 2.058s
* Dart Sass native executable: 2.152s
* Dart Sass on Node.js: 4.231s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.2x slower than libsass
* 2.0x faster than Dart Sass on Node

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of `.foo {a: b}`:

* sassc: 2.393s
* Dart Sass from a script snapshot: 2.981s
* Dart Sass native executable: 2.942s
* Dart Sass on Node.js: 9.858s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.2x slower than libsass
* 3.4x faster than Dart Sass on Node

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by `.bar {@extend .foo}`:

* sassc: 2.685s
* Dart Sass from a script snapshot: 3.838s
* Dart Sass native executable: 3.033s
* Dart Sass on Node.js: 9.527s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x slower than libsass
* 3.1x faster than Dart Sass on Node

## Bootstrap

Running on a file containing 16 instances of importing the Bootstrap framework:

* sassc: 0.891s
* Dart Sass from a script snapshot: 2.041s
* Dart Sass native executable: 0.787s
* Dart Sass on Node.js: 4.218s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 5.4x faster than Dart Sass on Node

## a11ycolor

Running on a file containing test cases for a computation-intensive color-processing library:

* sassc: 0.387s
* Dart Sass from a script snapshot: 0.970s
* Dart Sass native executable: 0.367s
* Dart Sass on Node.js: 1.409s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 3.8x faster than Dart Sass on Node

## Duomo

Running on a file containing the output of the numerically-intensive Duomo framework (skipping LibSass due to module system use):

* Dart Sass from a script snapshot: 3.946s
* Dart Sass native executable: 2.169s
* Dart Sass on Node.js: 7.108s

Based on these numbers, Dart Sass from a native executable is approximately:

* 3.3x faster than Dart Sass on Node

## Carbon

Running on a file containing the output of the import-intensive Carbon framework:

* sassc: 9.373s
* Dart Sass from a script snapshot: 7.454s
* Dart Sass native executable: 7.537s
* Dart Sass on Node.js: 25.790s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.2x faster than libsass
* 3.4x faster than Dart Sass on Node

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
