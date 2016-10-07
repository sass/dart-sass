These benchamrks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass eee6d59 and sassc 2fcd639 compiled with g++ 4.8.4.
* Dart Sass dfecdcd on Dart 1.19.1 and Node 4.6.0.
* Ruby Sass e79f5cf on Ruby 2.2.4p230.

on Ubuntu x64 with Intel Xeon E5-1650 v3 @ 3.50GHz.

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.003s
* Dart Sass from source: 0.255s
* Dart Sass from a snapshot: 0.193s
* Dart Sass on Node.js via dart2js: 0.227s
* Ruby Sass with a hot cache: 0.130s

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 1.972s
* Dart Sass from source: 2.597s
* Dart Sass from a snapshot: 2.547s
* Dart Sass on Node.js via dart2js: 4.971s
* Ruby Sass with a hot cache: 14.484s

Based on these numbers, Dart Sass is approximately:

* 1.3x slower than libsass
* 2x faster on the Dart VM than on Node
* 5.7x faster than Ruby Sass

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`,
and then `.y {a: b}`:

* sassc: 2.202s
* Dart Sass from a snapshot: 2.598s
* Dart Sass on Node.js via dart2js: 5.309s
* Ruby Sass with a hot cache: 22.423s

Based on these numbers, Dart Sass is approximately:

* 1.2x slower than libsass
* 2x faster on the Dart VM than on Node
* 8.6x faster than Ruby Sass

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`,
and then `.x {@extend .y}`:

* sassc: 2.207s
* Dart Sass from a snapshot: 2.569s
* Dart Sass on Node.js via dart2js: 5.053s
* Ruby Sass with a hot cache: 22.221s

Based on these numbers, Dart Sass is approximately:

* 1.2x slower than libsass
* 2x faster on the Dart VM than on Node
* 8.7x faster than Ruby Sass

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of
`.foo {a: b}`:

* sassc: 6.703s
* Dart Sass from a snapshot: 3.922s
* Dart Sass on Node.js via dart2js: 9.300s
* Ruby Sass with a hot cache: 40.193s

Based on these numbers, Dart Sass is approximately:

* 1.7x faster than libsass
* 2.4x faster on the Dart VM than on Node
* 10.3x faster than Ruby Sass

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by
`.bar {@extend .foo}`:

* sassc: 6.636s
* Dart Sass from a snapshot: 3.644s
* Dart Sass on Node.js via dart2js: 9.138s
* Ruby Sass with a hot cache: 39.603s

Based on these numbers, Dart Sass is approximately:

* 1.8x faster than libsass
* 2.5x faster on the Dart VM than on Node
* 10.9x faster than Ruby Sass

# Conclusions

Based on this (admittedly imperfect and non-representative) data, Dart Sass is
well within the desired performance bounds for large codebases. Because it
eagerly tracks data for `@extend`s, its worst case is when no `@extend`s are
present and that tracking proves unnecessary. However, even there it's only 2.2x
slower than libsass, and well within a reasonable amount of time to process over
130,000 selectors.

Because of the novel structuring of `@extend`, we see its relative performance
increase along with the amount of extension. With only one `@extend` it's almost
on par with libsass; with hundreds of thousands, it's actually faster.

It's worth noting that Dart Sass implements `@extend` semantics according to
[issue 1599][], while other implementations do not. This certainly simplifies
the implementation and may explain some of the speed gains. However, even if
other implementations could be faster, it's still the case that Dart Sass is
*fast enough*.

It's also interesting to note where Dart Sass falls when run on Node.js. It's
enough slower than the Dart VM that we probably don't want to position Node.js
as the primary way of running Sass, but it's still substantially faster than
Ruby. It probably makes sense to distribute Dart Sass through JS channels as an
low-overhead introduction, and then make it easy for users to upgrade to the
Dart version later on for more speed.

[1599]: https://github.com/sass/sass/issues/1599
