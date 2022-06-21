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
