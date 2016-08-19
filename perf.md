These benchamrks are informal and only intended to give us a general sense of
the benefit Dart Sass could provide relative to other implementations.

This was tested against:

* libsass 014a61b and sassc 014a61b.
* Dart Sass c63c440 on Dart 1.19.0-dev.7.0.
* Ruby Sass e79f5cf on Ruby 2.2.4p230.

# Measurements

I ran five instances of each configuration and recorded the fastest time.

## Small Plain CSS

Running on a file containing 4 instances of `.foo {a: b}`:

* sassc: 0.003s
* Dart Sass from source: 2.219s
* Dart Sass from a snapshot: 0.154s
* Ruby Sass with `--no-cache`: 0.135s
* Ruby Sass with a hot cache: 0.136s

## Large Plain CSS

Running on a file containing 2^17 instances of `.foo {a: b}`:

* sassc: 1.192s
* Dart Sass from source: 2.705s
* Dart Sass from a snapshot: 2.649s
* Ruby Sass with `--no-cache`: 17.429s
* Ruby Sass with a hot cache: 14.171s

Based on these numbers, Dart Sass is approximately:

* 2.2x slower than libsass
* 6.6x faster than Ruby Sass when it has to parse as well
* 5.4x faster than Ruby Sass with a hot cache

## Preceding Sparse `@extend`

Running on a file containing `.x {@extend .y}`, 2^17 instances of `.foo {a: b}`,
and then `.y {a: b}`:

* sassc: 2.153s
* Dart Sass from a snapshot: 2.766s
* Ruby Sass with a hot cache: 21.843s

Based on these numbers, Dart Sass is approximately:

* 1.3x slower than libsass
* 7.9x faster than Ruby Sass

## Following Sparse `@extend`

Running on a file containing `.y {a: b}`, 2^17 instances of `.foo {a: b}`,
and then `.x {@extend .y}`:

* sassc: 2.190s
* Dart Sass from a snapshot: 2.722s
* Ruby Sass with a hot cache: 21.970s

Based on these numbers, Dart Sass is approximately:

* 1.2x slower than libsass
* 8.1x faster than Ruby Sass

## Preceding Dense `@extend`

Running on a file containing `.bar {@extend .foo}` followed by 2^17 instances of
`.foo {a: b}`:

* sassc: 6.542s
* Dart Sass from a snapshot: 3.816s
* Ruby Sass with a hot cache: 39.099s

Based on these numbers, Dart Sass is approximately:

* 1.7x faster than libsass
* 10.3x faster than Ruby Sass

## Following Dense `@extend`

Running on a file containing 2^17 instances of `.foo {a: b}` followed by
`.bar {@extend .foo}`:

* sassc: 6.571s
* Dart Sass from a snapshot: 3.586s
* Ruby Sass with a hot cache: 40.705s

Based on these numbers, Dart Sass is approximately:

* 1.8x faster than libsass
* 11.4x faster than Ruby Sass

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

[1599]: https://github.com/sass/sass/issues/1599
