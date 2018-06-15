These benchmarks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass 45f50873 and sassc 2c2d264 compiled with g++ (Debian 7.3.0-5) 7.3.0.
* Dart Sass ad3feff on Dart 2.0.0-dev.62.0 and Node v9.5.0.
* Ruby Sass 36b0a0ba on ruby 2.4.1p111 (2017-03-22 revision 58053) [x86_64-linux].

on Debian x64 with Intel Xeon E5-1650 v3 @ 3.50GHz. The Dart Sass
[application snapshot][] was trained on the `tool/app-snapshot-input.scss` file.

[application snapshot]: https://github.com/dart-lang/sdk/wiki/Snapshots

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.002s
* Dart Sass from a script snapshot: 0.309s
* Dart Sass from an app snapshot: 0.072s
* Dart Sass on Node.js: 0.276s
* Ruby Sass with a hot cache: 0.141s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 36.0x slower than libsass
* 3.8x faster than Dart Sass on Node
* 2.0x faster than Ruby Sass

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 2.052s
* Dart Sass from a script snapshot: 2.132s
* Dart Sass from an app snapshot: 1.993s
* Dart Sass on Node.js: 4.957s
* Ruby Sass with a hot cache: 11.623s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* identical to libsass
* 2.5x faster than Dart Sass on Node
* 5.8x faster than Ruby Sass

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`, and then `.y {a: b}`:

* sassc: 2.171s
* Dart Sass from a script snapshot: 2.170s
* Dart Sass from an app snapshot: 2.007s
* Dart Sass on Node.js: 4.995s
* Ruby Sass with a hot cache: 17.434s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.1x faster than libsass
* 2.5x faster than Dart Sass on Node
* 8.7x faster than Ruby Sass

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`, and then `.x {@extend .y}`:

* sassc: 2.078s
* Dart Sass from a script snapshot: 2.153s
* Dart Sass from an app snapshot: 2.044s
* Dart Sass on Node.js: 4.925s
* Ruby Sass with a hot cache: 17.260s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* identical to libsass
* 2.4x faster than Dart Sass on Node
* 8.4x faster than Ruby Sass

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of `.foo {a: b}`:

* sassc: 2.212s
* Dart Sass from a script snapshot: 2.940s
* Dart Sass from an app snapshot: 2.906s
* Dart Sass on Node.js: 10.824s
* Ruby Sass with a hot cache: 33.666s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.3x slower than libsass
* 3.7x faster than Dart Sass on Node
* 11.6x faster than Ruby Sass

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by `.bar {@extend .foo}`:

* sassc: 2.136s
* Dart Sass from a script snapshot: 2.834s
* Dart Sass from an app snapshot: 2.722s
* Dart Sass on Node.js: 10.590s
* Ruby Sass with a hot cache: 33.264s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.3x slower than libsass
* 3.9x faster than Dart Sass on Node
* 23.2x faster than Ruby Sass

# Prior Measurements

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
