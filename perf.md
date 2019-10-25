These benchmarks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass ac338dfd and sassc a873899 compiled with g++ (Debian 7.3.0-18) 7.3.0.
* Dart Sass 143e02a on Dart 2.4.0 and Node v12.0.0.

on Debian x64 with Intel Xeon E5-1650 v3 @ 3.50GHz. The Dart Sass
[application snapshot][] was trained on the `tool/app-snapshot-input.scss` file.

[application snapshot]: https://github.com/dart-lang/sdk/wiki/Snapshots

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.005s
* Dart Sass from a script snapshot: 0.219s
* Dart Sass native executable: 0.019s
* Dart Sass on Node.js: 0.195s

Based on these numbers, Dart Sass from a native executable is approximately:

* 3.8x slower than libsass
* 10.3x faster than Dart Sass on Node

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 1.735s
* Dart Sass from a script snapshot: 1.573s
* Dart Sass native executable: 1.460s
* Dart Sass on Node.js: 2.729s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.2x faster than libsass
* 1.9x faster than Dart Sass on Node

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`, and then `.y {a: b}`:

* sassc: 1.739s
* Dart Sass from a script snapshot: 1.634s
* Dart Sass native executable: 1.574s
* Dart Sass on Node.js: 2.877s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.8x faster than Dart Sass on Node

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`, and then `.x {@extend .y}`:

* sassc: 1.726s
* Dart Sass from a script snapshot: 1.536s
* Dart Sass native executable: 1.512s
* Dart Sass on Node.js: 2.768s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.8x faster than Dart Sass on Node

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of `.foo {a: b}`:

* sassc: 2.356s
* Dart Sass from a script snapshot: 2.556s
* Dart Sass native executable: 2.628s
* Dart Sass on Node.js: 5.737s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x slower than libsass
* 2.2x faster than Dart Sass on Node

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by `.bar {@extend .foo}`:

* sassc: 2.377s
* Dart Sass from a script snapshot: 2.420s
* Dart Sass native executable: 2.440s
* Dart Sass on Node.js: 5.841s

Based on these numbers, Dart Sass from a native executable is approximately:

* identical to libsass
* 2.4x faster than Dart Sass on Node

## Bootstrap

Running on a file containing 16 instances of importing the Bootstrap framework:

* sassc: 0.820s
* Dart Sass from a script snapshot: 1.558s
* Dart Sass native executable: 0.927s
* Dart Sass on Node.js: 3.129s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x slower than libsass
* 3.4x faster than Dart Sass on Node

## a11ycolor

Running on a file containing test cases for a computation-intensive color-processing library:

* sassc: 0.264s
* Dart Sass from a script snapshot: 0.699s
* Dart Sass native executable: 0.375s
* Dart Sass on Node.js: 0.792s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.4x slower than libsass
* 2.1x faster than Dart Sass on Node

## Susy

Running on a file containing test cases for the computation-intensive Susy grid framework:

* sassc: 0.233s
* Dart Sass from a script snapshot: 0.694s
* Dart Sass native executable: 0.184s
* Dart Sass on Node.js: 0.909s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.3x faster than libsass
* 4.9x faster than Dart Sass on Node

# Prior Measurements

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