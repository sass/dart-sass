These benchmarks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass 27437bc and sassc 36eb82e compiled with g++ 4.8.4.
* Dart Sass 2bda8fa on Dart 1.22.0-dev.10.3 and Node 7.2.0.
* Ruby Sass e79f5cf on Ruby 2.2.4p230.

on Ubuntu x64 with Intel Xeon E5-1650 v3 @ 3.50GHz. The Dart Sass
[application snapshot][] was trained on the `preceding_sparse_extend.scss` file.

[application snapshot]: https://github.com/dart-lang/sdk/wiki/Snapshots

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.006s
* Dart Sass from source: 0.278s
* Dart Sass from a script snapshot: 0.206s
* Dart Sass from an app snapshot: 0.072s
* Dart Sass on Node.js via dart2js: 0.246s
* Ruby Sass with a hot cache: 0.130s

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 2.178s
* Dart Sass from source: 2.341s
* Dart Sass from a script snapshot: 2.291s
* Dart Sass from an app snapshot: 2.099s
* Dart Sass on Node.js via dart2js: 5.758s
* Ruby Sass with a hot cache: 14.484s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* identical to libsass
* 2.7x faster than Dart Sass on Node
* 6.9x faster than Ruby Sass

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`,
and then `.y {a: b}`:

* sassc: 2.338s
* Dart Sass from a script snapshot: 2.326s
* Dart Sass from an app snapshot: 2.123s
* Dart Sass on Node.js via dart2js: 6.082s
* Ruby Sass with a hot cache: 22.423s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.1x faster than libsass
* 2.9x faster than Dart Sass on Node
* 10.6x faster than Ruby Sass

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`,
and then `.x {@extend .y}`:

* sassc: 2.363s
* Dart Sass from a script snapshot: 2.308s
* Dart Sass from an app snapshot: 2.143s
* Dart Sass on Node.js via dart2js: 6.045s
* Ruby Sass with a hot cache: 22.221s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 1.1x faster than libsass
* 2.8x faster on the Dart VM than on Node
* 10.4x faster than Ruby Sass

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of
`.foo {a: b}`:

* sassc: 6.826s
* Dart Sass from a script snapshot: 3.324s
* Dart Sass from an app snapshot: 3.086s
* Dart Sass on Node.js via dart2js: 12.054s
* Ruby Sass with a hot cache: 40.193s

Based on these numbers, Dart Sass from an app snapshot is approximately:

* 2.2x faster than libsass
* 3.9x faster on the Dart VM than on Node
* 13.0x faster than Ruby Sass

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by
`.bar {@extend .foo}`:

* sassc: 6.796s
* Dart Sass from a script snapshot: 3.751s
* Dart Sass from an app snapshot: 3.339s
* Dart Sass on Node.js via dart2js: 11.551s
* Ruby Sass with a hot cache: 39.603s

Based on these numbers, Dart Sass is approximately:

* 2.0x faster than libsass
* 3.5x faster on the Dart VM than on Node
* 11.9x faster than Ruby Sass

# Conclusions

Based on this (admittedly imperfect and non-representative) data, Dart Sass can
match the best performance of any Sass implementation. Because it eagerly tracks
data for `@extend`s, its worst case is when no `@extend`s are present and that
tracking proves unnecessary. However, even there it matches the speed of the
pure-C++ LibSass implementation.

Because of the novel structuring of `@extend`, we see its relative performance
increase along with the amount of extension. With only one `@extend` it's
slightly faster than LibSass; with hundreds of thousands, it's vastly faster.

It's worth noting that Dart Sass implements `@extend` semantics according to
[issue 1599][1599], while other implementations do not. This certainly simplifies
the implementation and may explain some of the speed gains. However, even if
other implementations could be faster, it's still the case that Dart Sass is
*fast enough*.

[1599]: https://github.com/sass/sass/issues/1599

The only place where Dart Sass falls behind LibSass is when processing small
files—it's difficult for any VM to beat the startup speed of C++. But the app
snapshot model means that it stays beneath the crucial 100ms limit for trivial
files, which means it will look effectively instantaneous to humans.

It's also interesting to note where Dart Sass falls when run on Node.js. It's
enough slower than the Dart VM that we probably don't want to position Node.js
as the primary way of running Sass, but it's still substantially faster than
Ruby. It probably makes sense to distribute Dart Sass through JS channels as an
low-overhead introduction, and then make it easy for users to upgrade to the
Dart version later on for more speed.
