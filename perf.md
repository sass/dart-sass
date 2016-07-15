Based on informal benchmarking of running various implementations over large
chunks of CSS containing only very simple style rules and declarations, I got
the following best run numbers:

* sassc: 1.439s
* Dart Sass: 2.301s
* Ruby Sass with a hot cache: 15.023s
* Ruby Sass without caching: 18.488s

Based on these numbers, Dart Sass is approximately:

* 1.6x slower than libsass
* 6.5x faster than Ruby Sass with a hot cache
* 8x faster than Ruby Sass when it has to parse as well
