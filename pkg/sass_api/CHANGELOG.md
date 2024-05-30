## 11.0.0

* **Breaking change:** Remove the `SassApiColor.hasCalculatedRgb` and
  `.hasCalculatedHsl` extension methods. These can now be determined by checking
  if `SassColor.space` is `KnownColorSpace.rgb` or `KnownColorSpace.hsl`,
  respectively.

* Added a `ColorSpace` class which represents the various color spaces defined
  in the CSS spec.

* Added `SassColor.space` which returns a color's color space.

* Added `SassColor.channels` and `.channelsOrNull` which returns a list
  of channel values, with missing channels converted to 0 or exposed as null,
  respectively.

* Added `SassColor.isLegacy`, `.isInGamut`, `.channel()`, `.isChannelMissing()`,
  `.isChannelPowerless()`, `.toSpace()`, `.toGamut()`, `.changeChannels()`, and
  `.interpolate()` which do the same thing as the Sass functions of the
  corresponding names.

* `SassColor.rgb()` now allows out-of-bounds and non-integer arguments.

* `SassColor.hsl()` and `.hwb()` now allow out-of-bounds arguments.

* Added `SassColor.hwb()`, `.srgb()`, `.srgbLinear()`, `.displayP3()`,
  `.a98Rgb()`, `.prophotoRgb()`, `.rec2020()`, `.xyzD50()`, `.xyzD65()`,
  `.lab()`, `.lch()`, `.oklab()`, `.oklch()`, and `.forSpace()` constructors.

* Deprecated `SassColor.red`, `.green`, `.blue`, `.hue`, `.saturation`,
  `.lightness`, `.whiteness`, and `.blackness` in favor of
  `SassColor.channel()`.

* Deprecated `SassColor.changeRgb()`, `.changeHsl()`, and `.changeHwb()` in
  favor of `SassColor.changeChannels()`.

* Added `SassNumber.convertValueToUnit()` as a shorthand for
  `SassNumber.convertValue()` with a single numerator.

* Added `InterpolationMethod` and `HueInterpolationMethod` which collectively
  represent the method to use to interpolate two colors.

* Added the `SassApiColorSpace` extension to expose additional members of
  `ColorSpace`.

* Added the `ColorChannel` class to represent information about a single channel
  of a color space.

* Added `SassNumber.convertValueToUnit()` as a shorthand for
  `SassNumber.convertValue()` with a single numerator.

## 10.4.3

* No user-visible changes.

## 10.4.2

* No user-visible changes.

## 10.4.1

* No user-visible changes.

## 10.4.0

* No user-visible changes.

## 10.3.0

* No user-visible changes.

## 10.2.1

* No user-visible changes.

## 10.2.0

* No user-visible changes.

## 10.1.1

* No user-visible changes.

## 10.1.0

* No user-visible changes.

## 10.0.0

* Remove the `allowPlaceholders` argument from `SelectorList.parse()`. Instead,
  it now has a more generic `plainCss` argument which tells it to parse the
  selector in plain CSS mode.

* Rename `SelectorList.resolveParentSelectors` to `SelectorList.nestWithin`.

## 9.5.0

* No user-visible changes.

## 9.4.2

* No user-visible changes.

## 9.4.1

* No user-visible changes.

## 9.4.0

* No user-visible changes.

## 9.3.0

* No user-visible changes.

## 9.2.7

* No user-visible changes.

## 9.2.6

* No user-visible changes.

## 9.2.5

* No user-visible changes.

## 9.2.4

* No user-visible changes.

## 9.2.3

* No user-visible changes.

## 9.2.2

* No user-visible changes.

## 9.2.1

* No user-visible changes.

## 9.2.0

* No user-visible changes.

## 9.1.0

* No user-visible changes.

## 9.0.0

* Remove the `CalculationExpression` class and the associated visitor methods.

* Add an `AstSearchVisitor` helper class.

* Add an `Interpolation.isPlain` getter.

## 8.2.1

* No user-visible changes.

## 8.2.0

* No user-visible changes.

## 8.1.1

* No user-visible changes.

## 8.1.0

* No user-visible changes.

## 8.0.0

* Various classes now use Dart 3 [class modifiers] to more specifically restrict
  their usage to the intended patterns.

  [class modifiers]: https://dart.dev/language/class-modifiers

* All uses of classes from the `tuple` package have been replaced by record
  types.

## 7.2.2

* No user-visible changes.

## 7.2.1

* No user-visible changes.

## 7.2.0

* No user-visible changes.

## 7.1.6

* No user-visible changes.

## 7.1.5

* No user-visible changes.

## 7.1.4

* No user-visible changes.

## 7.1.3

* No user-visible changes.

## 7.1.2

* No user-visible changes.

## 7.1.1

* No user-visible changes.

## 7.1.0

* No user-visible changes.

## 7.0.0

* Silent comments in SCSS that are separated by blank lines are now parsed as
  separate `SilentComment` nodes rather than a single conjoined node.

## 6.3.0

* No user-visible changes.

## 6.2.0

* No user-visible changes.

## 6.1.0

* No user-visible changes.

## 6.0.3

* No user-visible changes.

## 6.0.2

* No user-visible changes.

## 6.0.1

* No user-visible changes.

## 6.0.0

* **Breaking change:** All selector AST node constructors now require a
  `FileSpan` and expose a `span` field.

* **Breaking change:** The `CssStyleRule.selector` field is now a plain
  `SelectorList` rather than a `CssValue<SelectorList>`.

* **Breaking change:** The `ModifiableCssValue` class has been removed.

* Add an `InterpolationMap` class which represents a mapping from an
  interpolation's source to the string it generated.

* Add an `interpolationMap` parameter to `CssMediaQuery.parseList()`,
  `AtRootQuery.parse()`, `ComplexSelector.parse`, `CompoundSelector.parse`,
  `ListSelector.parse`, and `SimpleSelector.parse`.

* Add a `SelectorSearchVisitor` mixin, which can be used to return the first
  instance of a selector in an AST matching a certain criterion.

## 5.1.1

* No user-visible changes.

## 5.1.0

* Add `BinaryOperation.isAssociative`.

* Add a `ReplaceExpressionVisitor`, which recursively visits all expressions in
  an AST and rebuilds them with replacement components.

## 5.0.1

* No user-visible changes.

## 5.0.0

* **Breaking change:** Instead of a `Tuple`, `findDependencies()` now returns a
  `DependencyReport` object with named fields. This provides finer-grained
  access to import URLs, as well as information about `meta.load-css()` calls
  with non-interpolated string literal arguments.

## 4.2.2

* No user-visible changes.

## 4.2.1

* No user-visible changes.

## 4.2.0

* No user-visible changes.

## 4.1.2

* No user-visible changes.

## 4.1.1

* No user-visible changes.

## 4.1.0

* No user-visible changes.

## 4.0.0

* **Breaking change:** The first argument to `NumberExpression()` is now a
  `double` rather than a `num`.

* Add an optional `argumentName` parameter to `SassScriptException()` to make it
  easier to throw exceptions associated with particular argument names.

* Most APIs that previously returned `num` now return `double`. All APIs
  continue to _accept_ `num`, although in Dart 2.0.0 most of these APIs will be
  changed to accept only `double`.

## 3.0.4

* `UnaryOperationExpression`s with operator `not` now include a correct span,
  covering the expression itself instead of just the operator.

## 3.0.3

* No user-visible changes.

## 3.0.2

* No user-visible changes.

## 3.0.1

* No user-visible chances.

## 3.0.0

* **Breaking change:** Convert all visitor superclasses into mixins. This
  includes `RecursiveAstVisitor`, `RecursiveSelectorVisitor`,
  `RecursiveStatementVisitor`, and `StatementSearchVisitor`. This has several
  effects;

  * You must use `with` to mix in visitors rather than `extends`.

  * It's now possible to mix multiple visitors into the same class, which wasn't
    possible with `extends`.

  * Because [mixins can't be composed], when mixing in `RecursiveAstVisitor` you
    must explicitly mix in `RecursiveStatementVisitor` as well.

    [mixins can't be composed]: https://github.com/dart-lang/language/issues/540

* **Breaking change:** Replace the `minSpecificity` and `maxSpecificity` fields
  on `ComplexSelector`, `CompoundSelector`, and `SimpleSelector` with a single
  `specificity` field.

## 2.0.4

* No user-visible changes.

## 2.0.3

* No user-visible changes.

## 2.0.2

* No user-visible changes.

## 2.0.1

* No user-visible changes.

## 2.0.0

* Refactor the `CssMediaQuery` API to support new logical operators:

  * Rename the `features` field to `conditions`, to reflect the fact that it can
    contain more than just the `<media-feature>` production.

  * Add a `conjunction` field to track whether `conditions` are matched
    conjunctively or disjunctively.

  * Rename the default constructor to `CssMediaQuery.type()` to reflect the fact
    that it's no longer by far the most commonly used form of media query.

  * Add a required `conjunction` argument to `CssMediaQuery.condition()`.

  * Delete the `isCondition` getter.

* Provide access to Sass's selector AST, including the following classes:
  `Selector`, `ListSelector`, `ComplexSelector`, `ComplexSelectorComponent`,
  `Combinator`, `CompoundSelector`, `SimpleSelector`, `AttributeSelector`,
  `AttributeOperator`, `ClassSelector`, `IdSelector`, `ParentSelector`,
  `PlaceholderSelector`, `PseudoSelector`, `TypeSelector`, `UniversalSelector`,
  and `QualifiedName`.

* Provide access to the `SelectorVisitor` and `RecursiveSelectorVisitor`
  classes.

* Provide access to the `Value.assertSelector()`,
  `Value.assertComplexSelector()`, `Value.assertCompoundSelector()`, and
  `Value.assertSimpleSelector()` methods.

## 1.0.0

* First stable release.

* No user-visible changes since 1.0.0-beta.48.

## 1.0.0-beta.48

* No user-visible changes.

## 1.0.0-beta.47

* No user-visible changes.

## 1.0.0-beta.46

* No user-visible changes.

## 1.0.0-beta.45

* **Breaking change:** Replace `StaticImport.supports` and `StaticImport.media`
  with a unified `StaticImport.modifiers` field. Same for `CssImport`.

* Add `SupportsExpression`.

## 1.0.0-beta.44

* No user-visible changes.

## 1.0.0-beta.43

* No user-visible changes.

## 1.0.0-beta.42

* No user-visible changes.

## 1.0.0-beta.41

* No user-visible changes.

## 1.0.0-beta.40

* No user-visible changes.

## 1.0.0-beta.39

* No user-visible changes.

## 1.0.0-beta.38

* No user-visible changes.

## 1.0.0-beta.37

* No user-visible changes.

## 1.0.0-beta.36

* No user-visible changes.

## 1.0.0-beta.35

* No user-visible changes.

## 1.0.0-beta.34

* No user-visible changes.

## 1.0.0-beta.33

* No user-visible changes.

## 1.0.0-beta.32

* No user-visible changes.

## 1.0.0-beta.31

* No user-visible changes.

## 1.0.0-beta.30

* No user-visible changes.

## 1.0.0-beta.29

* No user-visible changes.

## 1.0.0-beta.28

* No user-visible changes.

## 1.0.0-beta.27

* No user-visible changes.

## 1.0.0-beta.26

* No user-visible changes.

## 1.0.0-beta.25

* No user-visible changes.

## 1.0.0-beta.24

* No user-visible changes.

## 1.0.0-beta.23

* No user-visible changes.

## 1.0.0-beta.22

* No user-visible changes.

## 1.0.0-beta.21

* No user-visible changes.

## 1.0.0-beta.20

* No user-visible changes.

## 1.0.0-beta.19

* No user-visible changes.

## 1.0.0-beta.18

* No user-visible changes.

## 1.0.0-beta.17

* No user-visible changes.

## 1.0.0-beta.16

* No user-visible changes.

## 1.0.0-beta.15

* Fix an issue where `RecursiveAstVisitor` was not implementing
  `visitCalculationExpression`.

## 1.0.0-beta.14

* Fix a bug where `RecursiveAstVisitor.visitAtRootRule` wouldn't visit any nodes
  interpolated into the `@at-root`'s query.

## 1.0.0-beta.13

* No user-visible changes.

## 1.0.0-beta.12

* No user-visible changes.

## 1.0.0-beta.11

* No user-visible changes.

## 1.0.0-beta.10

* No user-visible changes.

## 1.0.0-beta.9

* Add the `CalculationExpression` type to represent calculations in the Sass
  AST.

* Add the `ExpressionVisitor.visitCalculationExpression` method.

## 1.0.0-beta.8

* No user-visible changes.

## 1.0.0-beta.7

* No user-visible changes.

## 1.0.0-beta.6

* Add the `SassApiColor` extension to the "Value" DartDoc category.

## 1.0.0-beta.5

* Add `SassColor.hasCalculatedRgb` and `.hasCalculatedHsl` extension getters.

## 1.0.0-beta.4

* `UseRule`, `ForwardRule`, and `DynamicImport` now share a common `Dependency`
  interface that exposes a `url` getter and a `urlSpan` getter.

* `VariableDeclaration`, `MixinRule`, `FunctionRule`, `Argument`, and
  `ConfiguredVariable` now share a common `SassDeclaration` interface that
  exposes a `name` getter (with underscores converted to hyphens) and a
  `nameSpan` getter.

* Function calls with interpolation have now been split into their own AST node:
  `InterpolatedFunctionExpression`. `FunctionExpression.name` is now always a
  string (with underscores converted to hyphens). `FunctionExpression` also now
  has an `originalName` getter, which leaves underscores as-is.

* `VariableExpression`, `IncludeRule`, and `FunctionExpression` now share a
  common `SassReference` interface that exposes a `namespace` getter and a
  `name` getter (with underscores converted to hyphens), as well as
  corresponding `namespaceSpan` and `nameSpan` getters.

## 1.0.0-beta.3

* No user-visible changes.

## 1.0.0-beta.2

* No user-visible changes.

## 1.0.0-beta.1

* Initial beta release.
