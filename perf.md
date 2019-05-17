These benchmarks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass 8d220b74 and sassc 3f84e23 compiled with g++ (Debian 7.3.0-18) 7.3.0.
* Dart Sass 2868ab3 on Dart 2.3.0 and Node v11.14.0.
* Ruby Sass 8d1edc76 on ruby 2.5.3p105 (2018-10-18 revision 65156) [x86_64-linux].

on Debian x64 with Intel Xeon E5-1650 v3 @ 3.50GHz. The Dart Sass
[application snapshot][] was trained on the `tool/app-snapshot-input.scss` file.

[application snapshot]: https://github.com/dart-lang/sdk/wiki/Snapshots

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.004s
* Dart Sass from a script snapshot: 0.188s
* Dart Sass native executable: 0.014s
* Dart Sass on Node.js: 0.169s
* Ruby Sass with a hot cache: 0.151s

Based on these numbers, Dart Sass from a native executable is approximately:

* 3.5x slower than libsass
* 12.1x faster than Dart Sass on Node
* 10.8x faster than Ruby Sass

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 1.909s
* Dart Sass from a script snapshot: 1.586s
* Dart Sass native executable: 1.438s
* Dart Sass on Node.js: 3.028s
* Ruby Sass with a hot cache: 10.772s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.3x faster than libsass
* 2.1x faster than Dart Sass on Node
* 7.5x faster than Ruby Sass

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`, and then `.y {a: b}`:

* sassc: 2.007s
* Dart Sass from a script snapshot: 1.617s
* Dart Sass native executable: 1.457s
* Dart Sass on Node.js: 3.072s
* Ruby Sass with a hot cache: 16.456s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.4x faster than libsass
* 2.1x faster than Dart Sass on Node
* 11.3x faster than Ruby Sass

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`, and then `.x {@extend .y}`:

* sassc: 1.934s
* Dart Sass from a script snapshot: 1.594s
* Dart Sass native executable: 1.433s
* Dart Sass on Node.js: 3.099s
* Ruby Sass with a hot cache: 16.497s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.3x faster than libsass
* 2.2x faster than Dart Sass on Node
* 11.5x faster than Ruby Sass

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of `.foo {a: b}`:

* sassc: 2.033s
* Dart Sass from a script snapshot: 2.380s
* Dart Sass native executable: 2.398s
* Dart Sass on Node.js: 6.523s
* Ruby Sass with a hot cache: 29.717s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.2x slower than libsass
* 2.7x faster than Dart Sass on Node
* 12.4x faster than Ruby Sass

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by `.bar {@extend .foo}`:

* sassc: 2.065s
* Dart Sass from a script snapshot: 2.312s
* Dart Sass native executable: 2.256s
* Dart Sass on Node.js: 6.760s
* Ruby Sass with a hot cache: 28.755s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.1x slower than libsass
* 3.0x faster than Dart Sass on Node
* 12.7x faster than Ruby Sass

## Bootstrap

Running on a file containing 16 instances of importing the Bootstrap framework:

* sassc: 0.898s
* Dart Sass from a script snapshot: 1.550s
* Dart Sass native executable: 0.907s
* Dart Sass on Node.js: 3.559s
* Ruby Sass with a hot cache: 12.649s

Based on these numbers, Dart Sass from a native executable is approximately:

* identical to libsass
* 3.9x faster than Dart Sass on Node
* 13.9x faster than Ruby Sass

## a11ycolor

Running on a file containing test cases for a computation-intensive color-processing library:

* sassc: 0.332s
* Dart Sass from a script snapshot: 0.726s
* Dart Sass native executable: 0.564s
* Dart Sass on Node.js: 2.027s
* Ruby Sass with a hot cache: 5.020s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.7x slower than libsass
* 3.6x faster than Dart Sass on Node
* 8.9x faster than Ruby Sass

## Susy

Running on a file containing test cases for the computation-intensive Susy grid framework:

* sassc: 0.290s
* Dart Sass from a script snapshot: 0.649s
* Dart Sass native executable: 0.225s
* Dart Sass on Node.js: 1.293s
* Ruby Sass with a hot cache: 1.506s

Based on these numbers, Dart Sass from a native executable is approximately:

* 1.3x faster than libsass
* 5.7x faster than Dart Sass on Node
* 6.7x faster than Ruby Sass

# Prior Measurements

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
