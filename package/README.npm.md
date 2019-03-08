A pure JavaScript implementation of [Sass][sass]. **Sass makes CSS fun again**.

<table>
  <tr>
    <td>
      <img width="118px" alt="Sass logo" src="https://rawgit.com/sass/sass-site/master/source/assets/img/logos/logo.svg" />
    </td>
    <td valign="middle">
      <a href="https://www.npmjs.com/package/sass"><img width="100%" alt="npm statistics" src="https://nodei.co/npm/sass.png?downloads=true"></a>
    </td>
    <td valign="middle">
      <a href="https://travis-ci.org/sass/dart-sass"><img alt="Travis build status" src="https://api.travis-ci.org/sass/dart-sass.svg?branch=master"></a>
      <br>
      <a href="https://ci.appveyor.com/project/nex3/dart-sass"><img alt="Appveyor build status" src="https://ci.appveyor.com/api/projects/status/84rl9hvu8uoecgef?svg=true"></a>
    </td>
  </tr>
</table>

[sass]: https://sass-lang.com/

This package is a distribution of [Dart Sass][], compiled to pure JavaScript
with no native code or external dependencies. It provides a command-line `sass`
executable and a Node.js API.

[Dart Sass]: https://github.com/sass/dart-sass

* [Usage](#usage)
* [API](#api)
* [See Also](#see-also)
* [Behavioral Differences from Ruby Sass](#behavioral-differences-from-ruby-sass)

## Usage

You can install Sass globally using `npm install -g sass` which will provide
access to the `sass` executable. You can also add it to your project using
`npm install --save-dev sass`. This provides the executable as well as a
library:

[npm]: https://www.npmjs.com/package/sass

```js
var sass = require('sass');

sass.render({file: scss_filename}, function(err, result) { /* ... */ });

// OR

var result = sass.renderSync({file: scss_filename});
```

[See below](#api) for details on Dart Sass's JavaScript API.

## API

<!-- #include ../README.md "JavaScript API" -->

## See Also

* [Dart Sass][], from which this package is compiled, can be used either as a
  stand-alone executable or as a Dart library. Running Dart Sass on the Dart VM
  is substantially faster than running the pure JavaScript version, so this may
  be appropriate for performance-sensitive applications. The Dart API is also
  (currently) more user-friendly than the JavaScript API. See
  [the Dart Sass README][Using Dart Sass] for details on how to use it.

* [Node Sass][], which is a wrapper around [LibSass][], the C++ implementation
  of Sass. Node Sass supports the same API as this package and is also faster
  (although it's usually a little slower than Dart Sass). However, it requires a
  native library which may be difficult to install, and it's generally slower to
  add features and fix bugs.

[Using Dart Sass]: https://github.com/sass/dart-sass#using-dart-sass
[Node Sass]: https://www.npmjs.com/package/node-sass
[LibSass]: https://sass-lang.com/libsass

## Behavioral Differences from Ruby Sass

<!-- #include ../README.md "Behavioral Differences from Ruby Sass" -->
