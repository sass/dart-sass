A [PostCSS]-compatible CSS and [Sass] parser with full expression support.

<table>
  <tr>
    <td>
      <img width="118px" alt="Sass logo" src="https://rawgit.com/sass/sass-site/main/source/assets/img/logos/logo.svg" />
    </td>
    <td valign="middle">
      <a href="https://www.npmjs.com/package/sass-parser"><img width="100%" alt="npm statistics" src="https://nodei.co/npm/sass-parser.png?downloads=true"></a>
    </td>
    <td valign="middle">
      <a href="https://github.com/sass/dart-sass/actions"><img alt="GitHub actions build status" src="https://github.com/sass/dart-sass/workflows/CI/badge.svg"></a>
    </td>
    <td>
      <a href="https://front-end.social/@sass"><img alt="@sass@front-end.social on Fediverse" src="https://img.shields.io/mastodon/follow/110159358073946175?domain=https%3A%2F%2Ffront-end.social"></a>
      <br>
      <a href="https://twitter.com/SassCSS"><img alt="@SassCSS on Twitter" src="https://img.shields.io/twitter/follow/SassCSS?label=%40SassCSS&style=social"></a>
      <br>
      <a href="https://stackoverflow.com/questions/tagged/sass"><img alt="stackoverflow" src="https://img.shields.io/stackexchange/stackoverflow/t/sass?label=Sass%20questions&logo=stackoverflow&style=social"></a>
      <br>
      <a href="https://gitter.im/sass/sass?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge"><img alt="Gitter" src="https://img.shields.io/gitter/room/sass/sass?label=chat&logo=gitter&style=social"></a>
    </td>
  </tr>
</table>

[PostCSS]: https://postcss.org/
[Sass]: https://sass-lang.com/

**Warning:** `sass-parser` is still in active development, and is not yet
suitable for production use. At time of writing it only supports a small subset
of CSS and Sass syntax. In addition, it does not yet support parsing raws
(metadata about the original formatting of the document), which makes it
unsuitable for certain source-to-source transformations.

* [Using `sass-parser`](#using-sass-parser)
* [Why `sass-parser`?](#why-sass-parser)
* [API Documentation](#api-documentation)
* [PostCSS Compatibility](#postcss-compatibility)
  * [Statement API](#statement-api)
  * [Expression API](#expression-api)
  * [Constructing New Nodes](#constructing-new-nodes)

## Using `sass-parser`

1. Install the `sass-parser` package from the npm repository:

   ```sh
   npm install sass-parser
   ```

2. Use the `scss`, `sass`, or `css` [`Syntax` objects] exports to parse a file.

   ```js
   const sassParser = require('sass-parser');

   const root = sassParser.scss.parse(`
     @use 'colors';

     body {
       color: colors.$midnight-blue;
     }
   `);
   ```

3. Use the standard [PostCSS API] to inspect and edit the stylesheet:

   ```js
   const styleRule = root.nodes[1];
   styleRule.selector = '.container';

   console.log(root.toString());
   // @use 'colors';
   //
   // .container {
   //   color: colors.$midnight-blue;
   // }
   ```

4. Use new PostCSS-style APIs to inspect and edit expressions and Sass-specific
   rules:

   ```js
   root.nodes[0].namespace = 'c';
   const variable = styleRule.nodes[0].valueExpression;
   variable.namespace = 'c';

   console.log(root.toString());
   // @use 'colors' as c;
   //
   // .container {
   //   color: c.$midnight-blue;
   // }
   ```

[`Syntax` objects]: https://postcss.org/api/#syntax
[PostCSS API]: https://postcss.org/api/

## Why `sass-parser`?

We decided to expose [Dart Sass]'s parser as a JS API because we saw two needs
that were going unmet.

[Dart Sass]: https://sass-lang.com/dart-sass

First, there was no fully-compatible Sass parser. Although a [`postcss-scss`]
plugin did exist, its author [requested we create this package] to fix
compatibility issues, support [the indented syntax], and provide first-class
support for Sass-specific rules without needing them to be manually parsed by
each user.

[`postcss-scss`]: https://www.npmjs.com/package/postcss-scss
[requested we create this package]: https://github.com/sass/dart-sass/issues/88#issuecomment-270069138
[the indented syntax]: https://sass-lang.com/documentation/syntax/#the-indented-syntax

Moreover, there was no robust solution for parsing the expressions that are used
as the values of CSS declarations (as well as Sass variable values). This was
true even for plain CSS, and doubly problematic for Sass's particularly complex
expression syntax. The [`postcss-value-parser`] package hasn't been updated
since 2021, the [`postcss-values-parser`] since January 2022, and even the
excellent [`@csstools/css-parser-algorithms`] had limited PostCSS integration
and no intention of ever supporting Sass.

[`postcss-value-parser`]: https://www.npmjs.com/package/postcss-value-parser
[`postcss-values-parser`]: https://www.npmjs.com/package/postcss-values-parser
[`@csstools/css-parser-algorithms`]: https://www.npmjs.com/package/@csstools/css-parser-algorithms

The `sass-parser` package intends to solve these problems by providing a parser
that's battle-tested by millions of Sass users and flexible enough to support
use-cases that don't involve Sass at all. We intend it to be usable as a drop-in
replacement for the standard PostCSS parser, and for the new expression-level
APIs to feel highly familiar to anyone used to PostCSS.

## API Documentation

The source code is fully documented using [TypeDoc]. Hosted, formatted
documentation will be coming soon.

[TypeDoc]: https://typedoc.org

## PostCSS Compatibility

[PostCSS] is the most popular and long-lived CSS post-processing framework in
the world, and this package aims to be fully compatible with its API. Where we
add new features, we do so in a way that's as similar to PostCSS as possible,
re-using its types and even implementation wherever possible.

### Statement API

All statement-level [AST] nodes produced by `sass-parser`—style rules, at-rules,
declarations, statement-level comments, and the root node—extend the
corresponding PostCSS node types ([`Rule`], [`AtRule`], [`Declaration`],
[`Comment`], and [`Root`]). However, `sass-parser` has multiple subclasses for
many of its PostCSS superclasses. For example, `sassParser.PropertyDeclaration`
extends `postcss.Declaration`, but so does `sassParser.VariableDeclaration`. The
different `sass-parser` node types may be distinguished using the
`sassParser.Node.sassType` field.

[AST]: https://en.wikipedia.org/wiki/Abstract_syntax_tree
[`Rule`]: https://postcss.org/api/#rule
[`AtRule`]: https://postcss.org/api/#atrule
[`Declaration`]: https://postcss.org/api/#declaration
[`Comment`]: https://postcss.org/api/#comment
[`Root`]: https://postcss.org/api/#root

In addition to supporting the standard PostCSS properties like
`Declaration.value` and `Rule.selector`, `sass-parser` provides more detailed
parsed values. For example, `sassParser.Declaration.valueExpression` provides
the declaration's value as a fully-parsed syntax tree rather than a string, and
`sassParser.Rule.selectorInterpolation` provides access to any interpolated
expressions as in `.prefix-#{$variable} { /*...*/ }`. These parsed values are
automatically kept up-to-date with the standard PostCSS properties.

### Expression API

The expression-level AST nodes inherit from PostCSS's [`Node`] class but not any
of its more specific nodes. Nor do expressions support all the PostCSS `Node`
APIs: unlike statements, expressions that contain other expressions don't always
contain them as a clearly-ordered list, so methods like `Node.before()` and
`Node.next` aren't available. Just like with `sass-parser` statements, you can
distinguish between expressions using the `sassType` field.

[`Node`]: https://postcss.org/api/#node

Just like standard PostCSS nodes, expression nodes can be modified in-place and
these modifications will be reflected in the CSS output. Each expression type
has its own specific set of properties which can be read about in the expression
documentation.

### Constructing New Nodes

All Sass nodes, whether expressions, statements, or miscellaneous nodes like
`Interpolation`s, can be constructed as standard JavaScript objects:

```js
const sassParser = require('sass-parser');

const root = new sassParser.Root();
root.append(new sassParser.Declaration({
  prop: 'content',
  valueExpression: new sassParser.StringExpression({
    quotes: true,
    text: new sassParser.Interpolation({
      nodes: ["hello, world!"],
    }),
  }),
}));
```

However, the same shorthands can be used as when adding new nodes in standard
PostCSS, as well as a few new ones. Anything that takes an `Interpolation` can
be passed a string instead to represent plain text with no Sass expressions:

```js
const sassParser = require('sass-parser');

const root = new sassParser.Root();
root.append(new sassParser.Declaration({
  prop: 'content',
  valueExpression: new sassParser.StringExpression({
    quotes: true,
    text: "hello, world!",
  }),
}));
```

Because the mandatory properties for all node types are unambiguous, you can
leave out the `new ...()` call and just pass the properties directly:

```js
const sassParser = require('sass-parser');

const root = new sassParser.Root();
root.append({
  prop: 'content',
  valueExpression: {quotes: true, text: "hello, world!"},
});
```

You can even pass a string in place of a statement and PostCSS will parse it for
you! **Warning:** This currently uses the standard PostCSS parser, not the Sass
parser, and as such it does not support Sass-specific constructs.

```js
const sassParser = require('sass-parser');

const root = new sassParser.Root();
root.append('content: "hello, world!"');
```

### Known Incompatibilities

There are a few cases where an operation that's valid in PostCSS won't work with
`sass-parser`:

* Trying to convert a Sass-specific at-rule like `@if` or `@mixin` into a
  different at-rule by changing its name is not supported.

* Trying to add child nodes to a Sass statement that doesn't support children
  like `@use` or `@error` is not supported.

## Contributing

Before sending out a pull request, please run the following commands from the
`sass-parser` directory:

* `npm run check` - Runs `eslint`, and then tries to compile the package with
  `tsc`.

* `npm run test` - Runs all tests in the package.
