# `@extend` Logic

This directory contains most of the logic for running Sass's `@extend` rule.
This rule is probably the most complex corner of the Sass language, since it
involves both understanding the semantics of selectors _and_ being able to
combine them.

The high-level lifecycle of extensions is as follows:

1. When [the evaluator] encounters a style rule, it registers its selector in
   the [`ExtensionStore`] for the current module. This applies any extensions
   that have already been registered, then returns a _mutable_
   `Box<SelectorList>` that will get updated as extensions are applied.

   [the evaluator]: ../visitor/async_evaluate.dart
   [`ExtensionStore`]: extension_store.dart

2. When the evaluator encounters an `@extend`, it registers that in the current
   module's `ExtensionStore` as well. This updates any selectors that have
   already been registered with that extension, _and_ updates the extension's
   own extender (the selector that gets injected when the extension is applied,
   which is stored along with the extension). Note that the extender has to be
   extended separately from the selector in the style rule, because the latter
   gets redundant selectors trimmed eagerly and the former does not.

3. When the entrypoint stylesheet has been fully executed, the evaluator
   determines which extensions are visible from which modules and adds
   extensions from one store to one another accordingly using
   `ExtensionStore.addExtensions()`.

Otherwise, the process of [extending a selector] as described in the Sass spec
matches the logic here fairly closely. See `ExtensionStore._extendList()` for
the primary entrypoint for that logic.

[extending a selector]: https://github.com/sass/sass/blob/main/spec/at-rules/extend.md#extending-a-selector
