These benchmarks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass 0f3d6ad1 and sassc 4674821 compiled with g++ (Debian 7.3.0-18) 7.3.0.
* Dart Sass 088fc28 on Dart 2.4.0 and Node v12.0.0.
* Ruby Sass 8d1edc76 on ruby 2.5.3p105 (2018-10-18 revision 65156) [x86_64-linux].

on Debian x64 with Intel Xeon E5-1650 v3 @ 3.50GHz. The Dart Sass
[application snapshot][] was trained on the `tool/app-snapshot-input.scss` file.

[application snapshot]: https://github.com/dart-lang/sdk/wiki/Snapshots

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.004s
* Dart Sass from a script snapshot: 0.219s
* Dart Sass native executable: 0.020s
* Dart Sass on Node.js: 0.200s
* Ruby Sass with a hot cache: 0.155s

Based on these numbers, Dart Sass from a native executable is approximately:

* 5.0x slower than libsass
* 10.0x faster than Dart Sass on Node
* 7.8x faster than Ruby Sass

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 1.714s
* Dart Sass from a script snapshot: 1.606s
* Dart Sass native executable: 1.547s
* Dart Sass on Node.js: 2.672s
* Ruby Sass with a hot cache: 11.145s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.7x faster than Dart Sass on Node
* 7.2x faster than Ruby Sass

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`, and then `.y {a: b}`:

* sassc: 1.750s
* Dart Sass from a script snapshot: 1.602s
* Dart Sass native executable: 1.585s
* Dart Sass on Node.js: 2.782s
* Ruby Sass with a hot cache: 17.012s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.8x faster than Dart Sass on Node
* 10.7x faster than Ruby Sass

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`, and then `.x {@extend .y}`:

* sassc: 1.724s
* Dart Sass from a script snapshot: 1.610s
* Dart Sass native executable: 1.568s
* Dart Sass on Node.js: 2.712s
* Ruby Sass with a hot cache: 16.670s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x faster than libsass
* 1.7x faster than Dart Sass on Node
* 10.6x faster than Ruby Sass

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of `.foo {a: b}`:

* sassc: 2.290s
* Dart Sass from a script snapshot: 2.476s
* Dart Sass native executable: 2.566s
* Dart Sass on Node.js: 5.399s
* Ruby Sass with a hot cache: 29.002s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x slower than libsass
* 2.1x faster than Dart Sass on Node
* 11.3x faster than Ruby Sass

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by `.bar {@extend .foo}`:

* sassc: 2.317s
* Dart Sass from a script snapshot: 2.381s
* Dart Sass native executable: 2.461s
* Dart Sass on Node.js: 5.481s
* Ruby Sass with a hot cache: 29.197s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x slower than libsass
* 2.2x faster than Dart Sass on Node
* 11.9x faster than Ruby Sass

## Bootstrap

Running on a file containing 16 instances of importing the Bootstrap framework:

* sassc: 0.763s
* Dart Sass from a script snapshot: 1.613s
* Dart Sass native executable: 0.992s
* Dart Sass on Node.js: 3.529s
* Ruby Sass with a hot cache: 12.969s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.3x slower than libsass
* 3.6x faster than Dart Sass on Node
* 13.1x faster than Ruby Sass

## a11ycolor

Running on a file containing test cases for a computation-intensive color-processing library:

* sassc: 0.262s
* Dart Sass from a script snapshot: 0.805s
* Dart Sass native executable: 0.612s
* Dart Sass on Node.js: 1.876s
* Ruby Sass with a hot cache: 5.396s

Based on these numbers, Dart Sass from a native executable is approximately:

* 2.3x slower than libsass
* 3.1x faster than Dart Sass on Node
* 8.8x faster than Ruby Sass

## Susy

Running on a file containing test cases for the computation-intensive Susy grid framework:

* sassc: 0.244s
* Dart Sass from a script snapshot: 0.673s
* Dart Sass native executable: 0.248s
* Dart Sass on Node.js: 1.361s
* Ruby Sass with a hot cache: 1.576s

Based on these numbers, Dart Sass from a native executable is approximately:

* identical to libsass
* 5.5x faster than Dart Sass on Node
* 6.4x faster than Ruby Sass

# Prior Measurements

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
