These benchmarks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass 0331b61b and sassc 43c4000 compiled with g++ (Debian 7.3.0-5) 7.3.0.
* Dart Sass ff3cea5 on Dart 2.0.0 and  and Node v10.5.0.
* Ruby Sass 4cf46cc4 on ruby 2.4.1p111 (2017-03-22 revision 58053) [x86_64-linux].

on Debian x64 with Intel Xeon E5-1650 v3 @ 3.50GHz. The Dart Sass
[application snapshot][] was trained on the `tool/app-snapshot-input.scss` file.

[application snapshot]: https://github.com/dart-lang/sdk/wiki/Snapshots

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.004s
* Dart Sass from a Dart 1 script snapshot: 0.238s
* Dart Sass from a Dart 1 app snapshot: 0.080s
* Dart Sass from a Dart 2 script snapshot: 0.221s
* Dart Sass from a Dart 2 app snapshot: 0.112s
* Dart Sass on Node.js: 0.179s
* Ruby Sass with a hot cache: 0.150s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 20.0x slower than libsass
* 1.4x faster than Dart 2
* 2.2x faster than Dart Sass on Node
* 1.9x faster than Ruby Sass

A Dart 1 script snapshot is approximately 1.1x slower than Dart 2.

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 2.150s
* Dart Sass from a Dart 1 script snapshot: 2.000s
* Dart Sass from a Dart 1 app snapshot: 1.888s
* Dart Sass from a Dart 2 script snapshot: 1.783s
* Dart Sass from a Dart 2 app snapshot: 1.802s
* Dart Sass on Node.js: 3.511s
* Ruby Sass with a hot cache: 12.397s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.1x faster than libsass
* identical to Dart 2
* 1.9x faster than Dart Sass on Node
* 6.6x faster than Ruby Sass

A Dart 1 script snapshot is approximately 1.1x slower than Dart 2.

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`, and then `.y {a: b}`:

* sassc: 2.282s
* Dart Sass from a Dart 1 script snapshot: 2.034s
* Dart Sass from a Dart 1 app snapshot: 1.932s
* Dart Sass from a Dart 2 script snapshot: 1.819s
* Dart Sass from a Dart 2 app snapshot: 1.768s
* Dart Sass on Node.js: 3.752s
* Ruby Sass with a hot cache: 18.894s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.2x faster than libsass
* 1.1x slower than Dart 2
* 1.9x faster than Dart Sass on Node
* 9.8x faster than Ruby Sass

A Dart 1 script snapshot is approximately 1.1x slower than Dart 2.

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`, and then `.x {@extend .y}`:

* sassc: 2.156s
* Dart Sass from a Dart 1 script snapshot: 1.966s
* Dart Sass from a Dart 1 app snapshot: 1.826s
* Dart Sass from a Dart 2 script snapshot: 1.769s
* Dart Sass from a Dart 2 app snapshot: 1.737s
* Dart Sass on Node.js: 3.446s
* Ruby Sass with a hot cache: 18.356s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.2x faster than libsass
* 1.1x slower than Dart 2
* 1.9x faster than Dart Sass on Node
* 10.1x faster than Ruby Sass

A Dart 1 script snapshot is approximately 1.1x slower than Dart 2.

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of `.foo {a: b}`:

* sassc: 2.270s
* Dart Sass from a Dart 1 script snapshot: 2.850s
* Dart Sass from a Dart 1 app snapshot: 2.813s
* Dart Sass from a Dart 2 script snapshot: 2.684s
* Dart Sass from a Dart 2 app snapshot: 2.714s
* Dart Sass on Node.js: 8.050s
* Ruby Sass with a hot cache: 32.530s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.2x slower than libsass
* identical to Dart 2
* 2.9x faster than Dart Sass on Node
* 11.6x faster than Ruby Sass

A Dart 1 script snapshot is approximately 1.1x slower than Dart 2.

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by `.bar {@extend .foo}`:

* sassc: 2.195s
* Dart Sass from a Dart 1 script snapshot: 2.836s
* Dart Sass from a Dart 1 app snapshot: 2.691s
* Dart Sass from a Dart 2 script snapshot: 2.613s
* Dart Sass from a Dart 2 app snapshot: 2.617s
* Dart Sass on Node.js: 7.855s
* Ruby Sass with a hot cache: 33.249s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.2x slower than libsass
* identical to Dart 2
* 2.9x faster than Dart Sass on Node
* 12.4x faster than Ruby Sass

A Dart 1 script snapshot is approximately 1.1x slower than Dart 2.

## Bootstrap

Running on a file containing 16 instances of importing the Bootstrap framework:

* sassc: 1.089s
* Dart Sass from a Dart 1 script snapshot: 1.564s
* Dart Sass from a Dart 1 app snapshot: 1.399s
* Dart Sass from a Dart 2 script snapshot: 1.691s
* Dart Sass from a Dart 2 app snapshot: 1.620s
* Dart Sass on Node.js: 3.747s
* Ruby Sass with a hot cache: 13.222s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.3x slower than libsass
* 1.2x faster than Dart 2
* 2.7x faster than Dart Sass on Node
* 9.5x faster than Ruby Sass

A Dart 1 script snapshot is approximately 1.1x faster than Dart 2.

## a11ycolor

Running on a file containing test cases for a computation-intensive color-processing library:

* sassc: 0.385s
* Dart Sass from a Dart 1 script snapshot: 0.790s
* Dart Sass from a Dart 1 app snapshot: 0.592s
* Dart Sass from a Dart 2 script snapshot: 0.782s
* Dart Sass from a Dart 2 app snapshot: 0.680s
* Dart Sass on Node.js: 2.438s
* Ruby Sass with a hot cache: 5.804s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.5x slower than libsass
* 1.1x faster than Dart 2
* 4.1x faster than Dart Sass on Node
* 9.8x faster than Ruby Sass

A Dart 1 script snapshot is approximately identical to Dart 2.

## Susy

Running on a file containing test cases for the computation-intensive Susy grid framework:

* sassc: 0.320s
* Dart Sass from a Dart 1 script snapshot: 0.688s
* Dart Sass from a Dart 1 app snapshot: 0.522s
* Dart Sass from a Dart 2 script snapshot: 0.741s
* Dart Sass from a Dart 2 app snapshot: 0.640s
* Dart Sass on Node.js: 1.479s
* Ruby Sass with a hot cache: 1.730s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.6x slower than libsass
* 1.2x faster than Dart 2
* 2.8x faster than Dart Sass on Node
* 3.3x faster than Ruby Sass

A Dart 1 script snapshot is approximately 1.1x faster than Dart 2.

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
