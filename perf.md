These benchmarks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass 0f3d6ad1 and sassc 4674821 compiled with g++ (Debian 7.3.0-18) 7.3.0.
* Dart Sass 50a45a7 on Dart 2.4.0 and Node v12.0.0.
* Ruby Sass 8d1edc76 on ruby 2.5.3p105 (2018-10-18 revision 65156) [x86_64-linux].

on Debian x64 with Intel Xeon E5-1650 v3 @ 3.50GHz. The Dart Sass
[application snapshot][] was trained on the `tool/app-snapshot-input.scss` file.

[application snapshot]: https://github.com/dart-lang/sdk/wiki/Snapshots

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.005s
* Dart Sass from a script snapshot: 0.216s
* Dart Sass native executable: 0.018s
* Dart Sass on Node.js: 0.209s
* Ruby Sass with a hot cache: 0.148s

Based on these numbers, Dart Sass from a native executable is approximately:

* 3.6x slower than libsass
* 11.6x faster than Dart Sass on Node
* 8.2x faster than Ruby Sass

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 1.705s
* Dart Sass from a script snapshot: 1.550s
* Dart Sass native executable: 1.518s
* Dart Sass on Node.js: 2.765s
* Ruby Sass with a hot cache: 10.965s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.8x faster than Dart Sass on Node
* 7.2x faster than Ruby Sass

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`, and then `.y {a: b}`:

* sassc: 1.712s
* Dart Sass from a script snapshot: 1.613s
* Dart Sass native executable: 1.582s
* Dart Sass on Node.js: 2.739s
* Ruby Sass with a hot cache: 16.472s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.7x faster than Dart Sass on Node
* 10.4x faster than Ruby Sass

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`, and then `.x {@extend .y}`:

* sassc: 1.701s
* Dart Sass from a script snapshot: 1.568s
* Dart Sass native executable: 1.543s
* Dart Sass on Node.js: 2.821s
* Ruby Sass with a hot cache: 16.469s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.8x faster than Dart Sass on Node
* 10.7x faster than Ruby Sass

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of `.foo {a: b}`:

* sassc: 2.260s
* Dart Sass from a script snapshot: 2.405s
* Dart Sass native executable: 2.526s
* Dart Sass on Node.js: 5.612s
* Ruby Sass with a hot cache: 28.690s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x slower than libsass
* 2.2x faster than Dart Sass on Node
* 11.4x faster than Ruby Sass

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by `.bar {@extend .foo}`:

* sassc: 2.289s
* Dart Sass from a script snapshot: 2.396s
* Dart Sass native executable: 2.457s
* Dart Sass on Node.js: 6.319s
* Ruby Sass with a hot cache: 28.708s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x slower than libsass
* 2.6x faster than Dart Sass on Node
* 11.7x faster than Ruby Sass

## Bootstrap

Running on a file containing 16 instances of importing the Bootstrap framework:

* sassc: 0.767s
* Dart Sass from a script snapshot: 1.534s
* Dart Sass native executable: 0.955s
* Dart Sass on Node.js: 3.156s
* Ruby Sass with a hot cache: 12.521s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.2x slower than libsass
* 3.3x faster than Dart Sass on Node
* 13.1x faster than Ruby Sass

## a11ycolor

Running on a file containing test cases for a computation-intensive color-processing library:

* sassc: 0.248s
* Dart Sass from a script snapshot: 0.736s
* Dart Sass native executable: 0.565s
* Dart Sass on Node.js: 1.043s
* Ruby Sass with a hot cache: 5.091s

Based on these numbers, Dart Sass from a native executable is approximately:

* 2.3x slower than libsass
* 1.8x faster than Dart Sass on Node
* 9.0x faster than Ruby Sass

## Susy

Running on a file containing test cases for the computation-intensive Susy grid framework:

* sassc: 0.248s
* Dart Sass from a script snapshot: 0.673s
* Dart Sass native executable: 0.237s
* Dart Sass on Node.js: 0.990s
* Ruby Sass with a hot cache: 1.527s

Based on these numbers, Dart Sass from a native executable is approximately:

* identical to libsass
* 4.2x faster than Dart Sass on Node
* 6.4x faster than Ruby Sass

# Prior Measurements

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

[embedded Dart Sass]: https://github.com/sass/sass-embedded-protocol
[Dart WebAssembly support]: https://github.com/dart-lang/sdk/issues/32894
