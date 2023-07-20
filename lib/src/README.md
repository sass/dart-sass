## The Sass Compiler

* [Life of a Compilation](#life-of-a-compilation)
  * [Late Parsing](#late-parsing)
  * [Early Serialization](#early-serialization)
* [JS Support](#js-support)
* [APIs](#apis)
  * [Importers](#importers)
  * [Custom Functions](#custom-functions)
  * [Loggers](#loggers)
* [Built-In Functions](#built-in-functions)
* [`@extend`](#extend)

This is the root directory of Dart Sass's private implementation libraries. This
contains essentially all the business logic defining how Sass is actually
compiled, as well as the APIs that users use to interact with Sass. There are
two exceptions:

* [`../../bin/sass.dart`] is the entrypoint for the Dart Sass CLI (on all
  platforms). While most of the logic it runs exists in this directory, it does
  contain some logic to drive the basic compilation logic and handle errors. All
  the most complex parts of the CLI, such as option parsing and the `--watch`
  command, are handled in the [`executable`] directory. Even Embedded Sass runs
  through this entrypoint, although it gets immediately gets handed off to [the
  embedded compiler].

  [`../../bin/sass.dart`]: ../../bin/sass.dart
  [`executable`]: executable
  [the embedded compiler]: embedded/README.md

* [`../sass.dart`] is the entrypoint for the public Dart API. This is what's
  loaded when a Dart package imports Sass. It just contains the basic
  compilation functions, and exports the rest of the public APIs from this
  directory.

  [`../sass.dart`]: ../sass.dart

Everything else is contained here, and each file and most subdirectories have
their own documentation. But before you dive into those, let's take a look at
the general lifecycle of a Sass compilation.

### Life of a Compilation

Whether it's invoked through the Dart API, the JS API, the CLI, or the embedded
host, the basic process of a Sass compilation is the same. Sass is implemented
as an AST-walking [interpreter] that operates in roughly three passes:

[interpreter]: https://en.wikipedia.org/wiki/Interpreter_(computing)

1. **Parsing**. The first step of a Sass compilation is always to parse the
   source file, whether it's SCSS, the indented syntax, or CSS. The parsing
   logic lives in the [`parse`] directory, while the abstract syntax tree that
   represents the parsed file lives in [`ast/sass`].

   [`parse`]: parse/README.md
   [`ast/sass`]: ast/sass/README.md

2. **Evaluation**. Once a Sass file is parsed, it's evaluated by
   [`visitor/async_evaluate.dart`]. (Why is there both an async and a sync
   version of this file? See [Synchronizing] for details!) The evaluator handles
   all the Sass-specific logic: it resolves variables, includes mixins, executes
   control flow, and so on. As it goes, it builds up a new AST that represents
   the plain CSS that is the compilation result, which is defined in
   [`ast/css`].

   [`visitor/async_evaluate.dart`]: visitor/async_evaluate.dart
   [Synchronizing]: ../../CONTRIBUTING.md#synchronizing
   [`ast/css`]: ast/css/README.md

   Sass evaluation is almost entirely linear: it begins at the first statement
   of the file, evaluates it (which may involve evaluating its nested children),
   adds its result to the CSS AST, and then moves on to the second statement. On
   it goes until it reaches the end of the file, at which point it's done. The
   only exception is module resolution: every Sass module has its own compiled
   CSS AST, and once the entrypoint file is done compiling the evaluator will go
   back through these modules, resolve `@extend`s across them as necessary, and
   stitch them together into the final stylesheet.

   SassScript, the expression-level syntax, is handled by the same evaluator.
   The main difference between SassScript and statement-level evaluation is that
   the same SassScript values are used during evaluation _and_ as part of the
   CSS AST. This means that it's possible to end up with a Sass-specific value,
   such as a map or a first-class function, as the value of a CSS declaration.
   If that happens, the Serialization phase will signal an error when it
   encounters the invalid value.

3. **Serialization**. Once we have the CSS AST that represents the compiled
   stylesheet, we need to convert it into actual CSS text. This is done by
   [`visitor/serialize.dart`], which walks the AST and builds up a big buffer of
   the resulting CSS. It uses [a special string buffer] that tracks source and
   destination locations in order to generate [source maps] as well.

   [`visitor/serialize.dart`]: visitor/serialize.dart
   [a special string buffer]: util/source_map_buffer.dart
   [source maps]: https://web.dev/source-maps/

There's actually one slight complication here: the first and second pass aren't
as separate as they appear. When one Sass stylesheet loads another with `@use`,
`@forward`, or `@import`, that rule is handled by the evaluator and _only at
that point_ is the loaded file parsed. So in practice, compilation actually
switches between parsing and evaluation, although each individual stylesheet
naturally has to be parsed before it can be evaluated.

#### Late Parsing

Some syntax within a stylesheet is only parsed _during_ evaluation. This allows
authors to use `#{}` interpolation to inject Sass variables and other dynamic
values into various locations, such as selectors, while still allowing Sass to
parse them to support features like nesting and `@extend`. The following
syntaxes are parsed during evaluation:

* [Selectors](parse/selector.dart)
* [`@keyframes` frames](parse/keyframe_selector.dart)
* [Media queries](parse/media_query.dart) (for historical reasons, these are
  parsed before evaluation and then _reparsed_ after they've been fully
  evaluated)

#### Early Serialization

There are also some cases where the evaluator can serialize values before the
main serialization pass. For example, if you inject a variable into a selector
using `#{}`, that variable's value has to be converted to a string during
evaluation so that the evaluator can then parse and handle the newly-generated
selector. The evaluator does this by invoking the serializer _just_ for that
specific value. As a rule of thumb, this happens anywhere interpolation is used
in the original stylesheet, although there are a few other circumstances as
well.

### JS Support

One of the main benefits of Dart as an implementation language is that it allows
us to distribute Dart Sass both as an extremely efficient stand-alone executable
_and_ an easy-to-install pure-JavaScript package, using the dart2js compilation
tool. However, properly supporting JS isn't seamless. There are two major places
where we need to think about JS support:

1. When interfacing with the filesystem. None of Dart's IO APIs are natively
   supported on JS, so for anything that needs to work on both the Dart VM _and_
   Node.js we define a shim in the [`io`] directory that will be implemented in
   terms of `dart:io` if we're running on the Dart VM or the `fs` or `process`
   modules if we're running on Node. (We don't support IO at all on the browser
   except to print messages to the console.)

   [`io`]: io/README.md

2. When exposing an API. Dart's JS interop is geared towards _consuming_ JS
   libraries from Dart, not producing a JS library written in Dart, so we have
   to jump through some hoops to make it work. This is all handled in the [`js`]
   directory.

   [`js`]: js/README.md

### APIs

One of Sass's core features is its APIs, which not only compile stylesheets but
also allow users to provide plugins that can be invoked from within Sass. In
both the JS API, the Dart API, and the embedded compiler, Sass provides three
types of plugins: importers, custom functions, and loggers.

#### Importers

Importers control how Sass loads stylesheets through `@use`, `@forward`, and
`@import`. Internally, _all_ stylesheet loads are modeled as importers. When a
user passes a load path to an API or compiles a stylesheet through the CLI, we
just use the built-in [`FilesystemImporter`] which implements the same interface
that we make available to users.

[`FilesystemImporter`]: importer/filesystem.dart

In the Dart API, the importer root class is [`importer/async_importer.dart`].
The JS API and the embedded compiler wrap the Dart importer API in
[`importer/node_to_dart`] and [`embedded/importer`] respectively.

[`importer/async_importer.dart`]: importer/async_importer.dart
[`importer/node_to_dart`]: importer/node_to_dart
[`embedded/importer`]: embedded/importer

#### Custom Functions

Custom functions are defined by users of the Sass API but invoked by Sass
stylesheets. To a Sass stylesheet, they look like any other built-in function:
users pass SassScript values to them and get SassScript values back. In fact,
all the core Sass functions are implemented using the Dart custom function API.

Because custom functions take and return SassScript values, that means we need
to make _all_ values available to the various APIs. For Dart, this is
straightforward: we need to have objects to represent those values anyway, so we
just expose those objects publicly (with a few `@internal` annotations here and
there to hide APIs we don't want users relying on). These value types live in
the [`value`] directory.

[`value`]: value/README.md

Exposing values is a bit more complex for other platforms. For the JS API, we do
a bit of metaprogramming in [`node/value`] so that we can return the
same Dart values we use internally while still having them expose a JS API that
feels native to that language. For the embedded host, we convert them to and
from a protocol buffer representation in [`embedded/value.dart`].

[`node/value`]: node/value/README.md
[`embedded/value.dart`]: embedded/value.dart

#### Loggers

Loggers are the simplest of the plugins. They're just callbacks that are invoked
any time Dart Sass would emit a warning (from the language or from `@warn`) or a
debug message from `@debug`. They're defined in:

* [`logger.dart`](logger.dart) for Dart
* [`node/logger.dart`](node/logger.dart) for Node
* [`embedded/logger.dart`](embedded/logger.dart) for the embedded compiler

### Built-In Functions

All of Sass's built-in functions are defined in the [`functions`] directory,
including both global functions and functions defined in core modules like
`sass:math`. As mentioned before, these are defined using the standard custom
function API, although in a few cases they use additional private features like
the ability to define multiple overloads of the same function name.

[`functions`]: functions/README.md

### `@extend`

The logic for Sass's `@extend` rule is particularly complex, since it requires
Sass to not only parse selectors but to understand how to combine them and when
they can be safely optimized away. Most of the logic for this is contained
within the [`extend`] directory.

[`extend`]: extend/README.md
