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
