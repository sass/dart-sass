These benchmarks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass d4d74ef5 and sassc 66f0ef3 compiled with g++ (Debian 10.2.0-16) 10.2.0.
* Dart Sass ae967c7 on Dart 2.10.4 (stable) (Wed Nov 11 13:35:58 2020 +0100) on "linux_x64" and Node v14.7.0.

on Debian x64 with Intel Core i7-8650U CPU @ 1.90GHz.

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.002s
* Dart Sass from a script snapshot: 0.179s
* Dart Sass native executable: 0.009s
* Dart Sass on Node.js: 0.248s

Based on these numbers, Dart Sass from a native executable is approximately:

* 4.5x slower than libsass
* 27.6x faster than Dart Sass on Node

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 1.770s
* Dart Sass from a script snapshot: 1.548s
* Dart Sass native executable: 1.379s
* Dart Sass on Node.js: 2.587s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.3x faster than libsass
* 1.9x faster than Dart Sass on Node

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`, and then `.y {a: b}`:

* sassc: 1.797s
* Dart Sass from a script snapshot: 1.594s
* Dart Sass native executable: 1.490s
* Dart Sass on Node.js: 2.783s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.2x faster than libsass
* 1.9x faster than Dart Sass on Node

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`, and then `.x {@extend .y}`:

* sassc: 1.902s
* Dart Sass from a script snapshot: 1.587s
* Dart Sass native executable: 1.425s
* Dart Sass on Node.js: 2.550s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.3x faster than libsass
* 1.8x faster than Dart Sass on Node

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of `.foo {a: b}`:

* sassc: 2.556s
* Dart Sass from a script snapshot: 2.426s
* Dart Sass native executable: 2.293s
* Dart Sass on Node.js: 4.843s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 2.1x faster than Dart Sass on Node

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by `.bar {@extend .foo}`:

* sassc: 2.567s
* Dart Sass from a script snapshot: 2.270s
* Dart Sass native executable: 2.174s
* Dart Sass on Node.js: 4.285s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.2x faster than libsass
* 2.0x faster than Dart Sass on Node

## Bootstrap

Running on a file containing 16 instances of importing the Bootstrap framework:

* sassc: 0.798s
* Dart Sass from a script snapshot: 1.417s
* Dart Sass native executable: 0.708s
* Dart Sass on Node.js: 2.832s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 4.0x faster than Dart Sass on Node

## a11ycolor

Running on a file containing test cases for a computation-intensive color-processing library:

* sassc: 0.239s
* Dart Sass from a script snapshot: 0.661s
* Dart Sass native executable: 0.319s
* Dart Sass on Node.js: 0.882s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.3x slower than libsass
* 2.8x faster than Dart Sass on Node

## Susy

Running on a file containing test cases for the computation-intensive Susy grid framework:

* sassc: 0.201s
* Dart Sass from a script snapshot: 0.706s
* Dart Sass native executable: 0.141s
* Dart Sass on Node.js: 1.187s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.4x faster than libsass
* 8.4x faster than Dart Sass on Node

## Duomo

Running on a file containing the output of the numerically-intensive Duomo framework:

* Dart Sass from a script snapshot: 2.017s
* Dart Sass native executable: 1.213s
* Dart Sass on Node.js: 3.632s

Based on these numbers, Dart Sass from a native executable is approximately:

* 3.0x faster than Dart Sass on Node

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
