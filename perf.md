These benchmarks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass 0331b61b and sassc 43c4000 compiled with g++ (Debian 7.3.0-5) 7.3.0.
* Dart Sass c0df461 on Dart 2.0.0 and Node v10.5.0.
* Ruby Sass 5dfe001a on ruby 2.4.1p111 (2017-03-22 revision 58053) [x86_64-linux].

on Debian x64 with Intel Xeon E5-1650 v3 @ 3.50GHz. The Dart Sass
[application snapshot][] was trained on the `tool/app-snapshot-input.scss` file.

[application snapshot]: https://github.com/dart-lang/sdk/wiki/Snapshots

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.004s
* Dart Sass from a Dart 1 script snapshot: 0.243s
* Dart Sass from a Dart 1 app snapshot: 0.076s
* Dart Sass from a Dart 2 script snapshot: 0.247s
* Dart Sass from a Dart 2 app snapshot: 0.128s
* Dart Sass on Node.js: 0.210s
* Ruby Sass with a hot cache: 0.147s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 19.0x slower than libsass
* 1.7x faster than Dart 2
* 2.8x faster than Dart Sass on Node
* 1.9x faster than Ruby Sass

A Dart 1 script snapshot is approximately identical to Dart 2.

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 2.125s
* Dart Sass from a Dart 1 script snapshot: 1.935s
* Dart Sass from a Dart 1 app snapshot: 1.816s
* Dart Sass from a Dart 2 script snapshot: 2.019s
* Dart Sass from a Dart 2 app snapshot: 1.954s
* Dart Sass on Node.js: 3.341s
* Ruby Sass with a hot cache: 12.179s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.2x faster than libsass
* 1.1x faster than Dart 2
* 1.8x faster than Dart Sass on Node
* 6.7x faster than Ruby Sass

A Dart 1 script snapshot is approximately identical to Dart 2.

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`, and then `.y {a: b}`:

* sassc: 2.200s
* Dart Sass from a Dart 1 script snapshot: 2.015s
* Dart Sass from a Dart 1 app snapshot: 1.896s
* Dart Sass from a Dart 2 script snapshot: 2.076s
* Dart Sass from a Dart 2 app snapshot: 2.009s
* Dart Sass on Node.js: 3.413s
* Ruby Sass with a hot cache: 18.670s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.2x faster than libsass
* 1.1x faster than Dart 2
* 1.8x faster than Dart Sass on Node
* 9.8x faster than Ruby Sass

A Dart 1 script snapshot is approximately identical to Dart 2.

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`, and then `.x {@extend .y}`:

* sassc: 2.136s
* Dart Sass from a Dart 1 script snapshot: 1.993s
* Dart Sass from a Dart 1 app snapshot: 1.858s
* Dart Sass from a Dart 2 script snapshot: 2.039s
* Dart Sass from a Dart 2 app snapshot: 1.966s
* Dart Sass on Node.js: 3.531s
* Ruby Sass with a hot cache: 18.524s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.1x faster than libsass
* 1.1x faster than Dart 2
* 1.9x faster than Dart Sass on Node
* 10.0x faster than Ruby Sass

A Dart 1 script snapshot is approximately identical to Dart 2.

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of `.foo {a: b}`:

* sassc: 2.264s
* Dart Sass from a Dart 1 script snapshot: 2.905s
* Dart Sass from a Dart 1 app snapshot: 2.848s
* Dart Sass from a Dart 2 script snapshot: 3.089s
* Dart Sass from a Dart 2 app snapshot: 3.076s
* Dart Sass on Node.js: 7.822s
* Ruby Sass with a hot cache: 33.592s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.3x slower than libsass
* 1.1x faster than Dart 2
* 2.7x faster than Dart Sass on Node
* 11.8x faster than Ruby Sass

A Dart 1 script snapshot is approximately 1.1x faster than Dart 2.

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by `.bar {@extend .foo}`:

* sassc: 2.203s
* Dart Sass from a Dart 1 script snapshot: 2.848s
* Dart Sass from a Dart 1 app snapshot: 2.654s
* Dart Sass from a Dart 2 script snapshot: 3.047s
* Dart Sass from a Dart 2 app snapshot: 3.014s
* Dart Sass on Node.js: 7.820s
* Ruby Sass with a hot cache: 32.730s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.2x slower than libsass
* 1.1x faster than Dart 2
* 2.9x faster than Dart Sass on Node
* 12.3x faster than Ruby Sass

A Dart 1 script snapshot is approximately 1.1x faster than Dart 2.

## Bootstrap

Running on a file containing 16 instances of importing the Bootstrap framework:

* sassc: 1.086s
* Dart Sass from a Dart 1 script snapshot: 1.576s
* Dart Sass from a Dart 1 app snapshot: 1.356s
* Dart Sass from a Dart 2 script snapshot: 1.841s
* Dart Sass from a Dart 2 app snapshot: 1.653s
* Dart Sass on Node.js: 3.743s
* Ruby Sass with a hot cache: 13.321s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.2x slower than libsass
* 1.2x faster than Dart 2
* 2.8x faster than Dart Sass on Node
* 9.8x faster than Ruby Sass

A Dart 1 script snapshot is approximately 1.2x faster than Dart 2.

## a11ycolor

Running on a file containing test cases for a computation-intensive color-processing library:

* sassc: 0.402s
* Dart Sass from a Dart 1 script snapshot: 0.755s
* Dart Sass from a Dart 1 app snapshot: 0.597s
* Dart Sass from a Dart 2 script snapshot: 0.838s
* Dart Sass from a Dart 2 app snapshot: 0.718s
* Dart Sass on Node.js: 2.339s
* Ruby Sass with a hot cache: 5.832s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.5x slower than libsass
* 1.2x faster than Dart 2
* 3.9x faster than Dart Sass on Node
* 9.8x faster than Ruby Sass

A Dart 1 script snapshot is approximately 1.1x faster than Dart 2.

## Susy

Running on a file containing test cases for the computation-intensive Susy grid framework:

* sassc: 0.319s
* Dart Sass from a Dart 1 script snapshot: 0.685s
* Dart Sass from a Dart 1 app snapshot: 0.521s
* Dart Sass from a Dart 2 script snapshot: 0.801s
* Dart Sass from a Dart 2 app snapshot: 0.628s
* Dart Sass on Node.js: 1.389s
* Ruby Sass with a hot cache: 1.738s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.6x slower than libsass
* 1.2x faster than Dart 2
* 2.7x faster than Dart Sass on Node
* 3.3x faster than Ruby Sass

A Dart 1 script snapshot is approximately 1.2x faster than Dart 2.

# Prior Measurements

* [1.6.0](https://github.com/sass/dart-sass/blob/048cbe197a77e1cf4b837a40a5acb737e949fd5c/perf.md).
* [1.0.0-alpha.8](https://github.com/sass/dart-sass/blob/be44245a849f2bb18b5ca1fc74f3043a36da17f0/perf.md).
* [Pre-alpha, 30 September 2016](https://github.com/sass/dart-sass/blob/169370bf18fd01d0618b0fc00d9db33e2fc52aa7/perf.md).
* [Pre-alpha, 19 August 2016](https://github.com/sass/dart-sass/blob/4bea13cfe57d9e3c7f1f8580b80c59abe1cfabf8/perf.md).
* [Pre-alpha, 15 July 2016](https://github.com/sass/dart-sass/blob/a3e00059c4371bfde9afada1759d8484aee05584/perf.md).

# Conclusions

Since the last measurement, both Dart Sass and LibSass performance numbers have
improved. LibSass has made major strides particularly in processing dense
extends, to the point that it's now faster than Dart Sass in those cases.

Overall, Dart Sass on the Dart VM is still neck-and-neck with LibSass in terms
of performance, and both are faster than they were at the time of Dart Sass's
initial release. They're well within the parameters for highly usable systems.

It's still the case that Dart Sass falls behind LibSass when processing small
files—it's difficult for any VM to beat the startup speed of C++. But the app
snapshot model means that it stays beneath the crucial 100ms limit for trivial
files, which means it will look effectively instantaneous to humans.

Dart Sass on Node lags behind, particularly when many extends are in use. It's
still faster than it was last measurement, but it would probably pay dividends
to do some JS-specific benchmarking and optimization to try to bring the speed
closer to that of the Dart VM. The majority of our users run Dart Sass through
JS, so while it's good that they have a path to better performance with the same
semantics, improving the baseline performance is important.

It's also still worth investigating the possibility of driving Dart Sass on the
Dart VM through Node.js, ideally supporting the standard JS API surface. While
this may add considerable overhead for custom functions, the gains in pure-Sass
processing times may well be worth it for some users.
