// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:source_span/source_span.dart';

import '../ast/css.dart';
import '../ast/selector.dart';
import '../ast/sass.dart';
import '../exception.dart';
import '../util/box.dart';
import '../util/map.dart';
import '../util/nullable.dart';
import '../utils.dart';
import 'empty_extension_store.dart';
import 'extension.dart';
import 'merged_extension.dart';
import 'functions.dart';
import 'mode.dart';

/// Tracks selectors and extensions, and applies the latter to the former.
class ExtensionStore {
  /// An [ExtensionStore] that contains no extensions and can have no extensions
  /// added.
  static const empty = EmptyExtensionStore();

  /// A map from all simple selectors in the stylesheet to the selector lists
  /// that contain them.
  ///
  /// This is used to find which selectors an `@extend` applies to and adjust
  /// them.
  final Map<SimpleSelector, Set<ModifiableBox<SelectorList>>> _selectors;

  /// A map from all extended simple selectors to the sources of those
  /// extensions.
  final Map<SimpleSelector, Map<ComplexSelector, Extension>> _extensions;

  /// A map from all simple selectors in extenders to the extensions that those
  /// extenders define.
  final Map<SimpleSelector, List<Extension>> _extensionsByExtender;

  /// A map from CSS selectors to the media query contexts they're defined in.
  ///
  /// This tracks the contexts in which each selector's style rule is defined.
  /// If a rule is defined at the top level, it doesn't have an entry.
  final Map<ModifiableBox<SelectorList>, List<CssMediaQuery>> _mediaContexts;

  /// A map from [SimpleSelector]s to the specificity of their source
  /// selectors.
  ///
  /// This tracks the maximum specificity of the [ComplexSelector] that
  /// originally contained each [SimpleSelector]. This allows us to ensure that
  /// we don't trim any selectors that need to exist to satisfy the [second law
  /// of extend][].
  ///
  /// [second law of extend]: https://github.com/sass/sass/issues/324#issuecomment-4607184
  final Map<SimpleSelector, int> _sourceSpecificity;

  /// A set of [ComplexSelector]s that were originally part of
  /// their component [SelectorList]s, as opposed to being added by `@extend`.
  ///
  /// This allows us to ensure that we don't trim any selectors that need to
  /// exist to satisfy the [first law of extend][].
  ///
  /// [first law of extend]: https://github.com/sass/sass/issues/324#issuecomment-4607184
  final Set<ComplexSelector> _originals;

  /// The mode that controls this extender's behavior.
  final ExtendMode _mode;

  /// Whether this extender has no extensions.
  bool get isEmpty => _extensions.isEmpty;

  /// Extends [selector] with [source] extender and [targets] extendees.
  ///
  /// This works as though `source {@extend target}` were written in the
  /// stylesheet, with the exception that [target] can contain compound
  /// selectors which must be extended as a unit.
  static SelectorList extend(SelectorList selector, SelectorList source,
          SelectorList targets, FileSpan span) =>
      _extendOrReplace(selector, source, targets, ExtendMode.allTargets, span);

  /// Returns a copy of [selector] with [targets] replaced by [source].
  static SelectorList replace(SelectorList selector, SelectorList source,
          SelectorList targets, FileSpan span) =>
      _extendOrReplace(selector, source, targets, ExtendMode.replace, span);

  /// A helper function for [extend] and [replace].
  static SelectorList _extendOrReplace(
      SelectorList selector,
      SelectorList source,
      SelectorList targets,
      ExtendMode mode,
      FileSpan span) {
    var extender = ExtensionStore._mode(mode);
    if (!selector.isInvisible) extender._originals.addAll(selector.components);

    for (var complex in targets.components) {
      var compound = complex.singleCompound;
      if (compound == null) {
        throw SassScriptException("Can't extend complex selector $complex.");
      }

      selector = extender._extendList(selector, {
        for (var simple in compound.components)
          simple: {
            for (var complex in source.components)
              complex: Extension(complex, simple, span, optional: true)
          }
      });
    }

    return selector;
  }

  /// The set of all simple selectors in selectors handled by this extender.
  ///
  /// This includes simple selectors that were added because of downstream
  /// extensions.
  Set<SimpleSelector> get simpleSelectors => MapKeySet(_selectors);

  ExtensionStore() : this._mode(ExtendMode.normal);

  ExtensionStore._mode(this._mode)
      : _selectors = {},
        _extensions = {},
        _extensionsByExtender = {},
        _mediaContexts = {},
        _sourceSpecificity = Map.identity(),
        _originals = Set.identity();

  ExtensionStore._(
      this._selectors,
      this._extensions,
      this._extensionsByExtender,
      this._mediaContexts,
      this._sourceSpecificity,
      this._originals)
      : _mode = ExtendMode.normal;

  /// Returns all mandatory extensions in this extender for whose targets
  /// [callback] returns `true`.
  ///
  /// This un-merges any [MergedExtension] so only base [Extension]s are
  /// returned.
  Iterable<Extension> extensionsWhereTarget(
      bool callback(SimpleSelector target)) sync* {
    for (var (simple, sources) in _extensions.pairs) {
      if (!callback(simple)) continue;
      for (var extension in sources.values) {
        if (extension is MergedExtension) {
          yield* extension
              .unmerge()
              .where((extension) => !extension.isOptional);
        } else if (!extension.isOptional) {
          yield extension;
        }
      }
    }
  }

  /// Adds [selector] to this extender.
  ///
  /// Extends [selector] using any registered extensions, then returns a [Box]
  /// containing the resulting selector. If any more relevant extensions are
  /// added, the returned selector is automatically updated.
  ///
  /// The [mediaContext] is the media query context in which the selector was
  /// defined, or `null` if it was defined at the top level of the document.
  Box<SelectorList> addSelector(SelectorList selector,
      [List<CssMediaQuery>? mediaContext]) {
    var originalSelector = selector;
    if (!originalSelector.isInvisible) {
      _originals.addAll(originalSelector.components);
    }

    if (_extensions.isNotEmpty) {
      try {
        selector = _extendList(originalSelector, _extensions, mediaContext);
      } on SassException catch (error, stackTrace) {
        throwWithTrace(
            SassException(
                "From ${error.span.message('')}\n"
                "${error.message}",
                error.span),
            error,
            stackTrace);
      }
    }

    var modifiableSelector = ModifiableBox(selector);
    if (mediaContext != null) _mediaContexts[modifiableSelector] = mediaContext;
    _registerSelector(selector, modifiableSelector);

    return modifiableSelector.seal();
  }

  /// Registers the [SimpleSelector]s in [list] to point to [selector] in
  /// [_selectors].
  void _registerSelector(
      SelectorList list, ModifiableBox<SelectorList> selector) {
    for (var complex in list.components) {
      for (var component in complex.components) {
        for (var simple in component.selector.components) {
          _selectors.putIfAbsent(simple, () => {}).add(selector);
          if (simple case PseudoSelector(selector: var selectorInPseudo?)) {
            _registerSelector(selectorInPseudo, selector);
          }
        }
      }
    }
  }

  /// Adds an extension to this extender.
  ///
  /// The [extender] is the selector for the style rule in which the extension
  /// is defined, and [target] is the selector passed to `@extend`. The [extend]
  /// provides the extend span and indicates whether the extension is optional.
  ///
  /// The [mediaContext] defines the media query context in which the extension
  /// is defined. It can only extend selectors within the same context. A `null`
  /// context indicates no media queries.
  void addExtension(
      SelectorList extender, SimpleSelector target, ExtendRule extend,
      [List<CssMediaQuery>? mediaContext]) {
    var selectors = _selectors[target];
    var existingExtensions = _extensionsByExtender[target];

    Map<ComplexSelector, Extension>? newExtensions;
    var sources = _extensions.putIfAbsent(target, () => {});
    for (var complex in extender.components) {
      if (complex.isUseless) continue;

      var extension = Extension(complex, target, extend.span,
          mediaContext: mediaContext, optional: extend.isOptional);

      if (sources[complex] case var existingExtension?) {
        // If there's already an extend from [extender] to [target], we don't need
        // to re-run the extension. We may need to mark the extension as
        // mandatory, though.
        sources[complex] = MergedExtension.merge(existingExtension, extension);
        continue;
      }
      sources[complex] = extension;

      for (var simple in _simpleSelectors(complex)) {
        _extensionsByExtender.putIfAbsent(simple, () => []).add(extension);
        // Only source specificity for the original selector is relevant.
        // Selectors generated by `@extend` don't get new specificity.
        _sourceSpecificity.putIfAbsent(simple, () => complex.specificity);
      }

      if (selectors != null || existingExtensions != null) {
        newExtensions ??= {};
        newExtensions[complex] = extension;
      }
    }

    if (newExtensions == null) return;

    var newExtensionsByTarget = {target: newExtensions};
    if (existingExtensions != null) {
      var additionalExtensions =
          _extendExistingExtensions(existingExtensions, newExtensionsByTarget);
      if (additionalExtensions != null) {
        mapAddAll2(newExtensionsByTarget, additionalExtensions);
      }
    }

    if (selectors != null) {
      _extendExistingSelectors(selectors, newExtensionsByTarget);
    }
  }

  /// Returns an iterable of all simple selectors in [complex]
  Iterable<SimpleSelector> _simpleSelectors(ComplexSelector complex) sync* {
    for (var component in complex.components) {
      for (var simple in component.selector.components) {
        yield simple;

        if (simple case PseudoSelector(:var selector?)) {
          for (var complex in selector.components) {
            yield* _simpleSelectors(complex);
          }
        }
      }
    }
  }

  /// Extend [extensions] using [newExtensions].
  ///
  /// Note that this does duplicate some work done by
  /// [_extendExistingSelectors], but it's necessary to expand each extension's
  /// extender separately without reference to the full selector list, so that
  /// relevant results don't get trimmed too early.
  ///
  /// Returns extensions that should be added to [newExtensions] before
  /// extending selectors in order to properly handle extension loops such as:
  ///
  ///     .c {x: y; @extend .a}
  ///     .x.y.a {@extend .b}
  ///     .z.b {@extend .c}
  ///
  /// Returns `null` if there are no extensions to add.
  Map<SimpleSelector, Map<ComplexSelector, Extension>>?
      _extendExistingExtensions(List<Extension> extensions,
          Map<SimpleSelector, Map<ComplexSelector, Extension>> newExtensions) {
    Map<SimpleSelector, Map<ComplexSelector, Extension>>? additionalExtensions;

    for (var extension in extensions.toList()) {
      var sources = _extensions[extension.target]!;

      Iterable<ComplexSelector>? selectors;
      try {
        selectors = _extendComplex(
            extension.extender.selector, newExtensions, extension.mediaContext);
        if (selectors == null) continue;
      } on SassException catch (error, stackTrace) {
        throwWithTrace(
            error.withAdditionalSpan(
                extension.extender.selector.span, "target selector"),
            error,
            stackTrace);
      }

      // If the output contains the original complex selector, there's no need
      // to recreate it.
      var containsExtension = selectors.first == extension.extender.selector;
      if (containsExtension) selectors = selectors.skip(1);

      for (var complex in selectors) {
        var withExtender = extension.withExtender(complex);
        if (sources[complex] case var existingExtension?) {
          sources[complex] =
              MergedExtension.merge(existingExtension, withExtender);
        } else {
          sources[complex] = withExtender;

          for (var component in complex.components) {
            for (var simple in component.selector.components) {
              _extensionsByExtender
                  .putIfAbsent(simple, () => [])
                  .add(withExtender);
            }
          }

          if (newExtensions.containsKey(extension.target)) {
            additionalExtensions ??= {};
            var additionalSources =
                additionalExtensions.putIfAbsent(extension.target, () => {});
            additionalSources[complex] = withExtender;
          }
        }
      }
    }

    return additionalExtensions;
  }

  /// Extend [extensions] using [newExtensions].
  void _extendExistingSelectors(Set<ModifiableBox<SelectorList>> selectors,
      Map<SimpleSelector, Map<ComplexSelector, Extension>> newExtensions) {
    for (var selector in selectors) {
      var oldValue = selector.value;
      try {
        selector.value = _extendList(
            selector.value, newExtensions, _mediaContexts[selector]);
      } on SassException catch (error, stackTrace) {
        // TODO(nweiz): Make this a MultiSpanSassException.
        throwWithTrace(
            SassException(
                "From ${selector.value.span.message('')}\n"
                "${error.message}",
                error.span),
            error,
            stackTrace);
      }

      // If no extends actually happened (for example because unification
      // failed), we don't need to re-register the selector.
      if (identical(oldValue, selector.value)) continue;
      _registerSelector(selector.value, selector);
    }
  }

  /// Extends `this` with all the extensions in [extensions].
  ///
  /// These extensions will extend all selectors already in `this`, but they
  /// will *not* extend other extensions from [extensionStores].
  void addExtensions(Iterable<ExtensionStore> extensionStores) {
    // Extensions already in `this` whose extenders are extended by
    // [extensions], and thus which need to be updated.
    List<Extension>? extensionsToExtend;

    // Selectors that contain simple selectors that are extended by
    // [extensions], and thus which need to be extended themselves.
    Set<ModifiableBox<SelectorList>>? selectorsToExtend;

    // An extension map with the same structure as [_extensions] that only
    // includes extensions from [extensionStores].
    Map<SimpleSelector, Map<ComplexSelector, Extension>>? newExtensions;

    for (var extensionStore in extensionStores) {
      if (extensionStore.isEmpty) continue;
      _sourceSpecificity.addAll(extensionStore._sourceSpecificity);
      for (var (target, newSources) in extensionStore._extensions.pairs) {
        // Private selectors can't be extended across module boundaries.
        if (target case PlaceholderSelector(isPrivate: true)) continue;

        // Find existing extensions to extend.
        var extensionsForTarget = _extensionsByExtender[target];
        if (extensionsForTarget != null) {
          (extensionsToExtend ??= []).addAll(extensionsForTarget);
        }

        // Find existing selectors to extend.
        var selectorsForTarget = _selectors[target];
        if (selectorsForTarget != null) {
          (selectorsToExtend ??= {}).addAll(selectorsForTarget);
        }

        // Add [newSources] to [_extensions].
        if (_extensions[target] case var existingSources?) {
          for (var (extender, extension) in newSources.pairs) {
            extension = existingSources.putOrMerge(
                extender, extension, MergedExtension.merge);

            if (extensionsForTarget != null || selectorsForTarget != null) {
              (newExtensions ??= {}).putIfAbsent(target, () => {})[extender] =
                  extension;
            }
          }
        } else {
          _extensions[target] = Map.of(newSources);
          if (extensionsForTarget != null || selectorsForTarget != null) {
            (newExtensions ??= {})[target] = Map.of(newSources);
          }
        }
      }
    }

    if (newExtensions != null) {
      // We can ignore the return value here because it's only useful for extend
      // loops, which can't exist across module boundaries.
      if (extensionsToExtend != null) {
        _extendExistingExtensions(extensionsToExtend, newExtensions);
      }

      if (selectorsToExtend != null) {
        _extendExistingSelectors(selectorsToExtend, newExtensions);
      }
    }
  }

  /// Extends [list] using [extensions].
  SelectorList _extendList(SelectorList list,
      Map<SimpleSelector, Map<ComplexSelector, Extension>> extensions,
      [List<CssMediaQuery>? mediaQueryContext]) {
    // This could be written more simply using [List.map], but we want to avoid
    // any allocations in the common case where no extends apply.
    List<ComplexSelector>? extended;
    for (var i = 0; i < list.components.length; i++) {
      var complex = list.components[i];
      var result = _extendComplex(complex, extensions, mediaQueryContext);
      assert(
          result?.isNotEmpty ?? true,
          '_extendComplex($complex) should return null rather than [] if '
          'extension fails');
      if (result == null) {
        extended?.add(complex);
      } else {
        extended ??= i == 0 ? [] : list.components.sublist(0, i).toList();
        extended.addAll(result);
      }
    }
    if (extended == null) return list;

    return SelectorList(_trim(extended, _originals.contains), list.span);
  }

  /// Extends [complex] using [extensions], and returns the contents of a
  /// [SelectorList].
  List<ComplexSelector>? _extendComplex(
      ComplexSelector complex,
      Map<SimpleSelector, Map<ComplexSelector, Extension>> extensions,
      List<CssMediaQuery>? mediaQueryContext) {
    if (complex.leadingCombinators.length > 1) return null;

    // The complex selectors that each compound selector in [complex.components]
    // can expand to.
    //
    // For example, given
    //
    //     .a .b {...}
    //     .x .y {@extend .b}
    //
    // this will contain
    //
    //     [
    //       [.a],
    //       [.b, .x .y]
    //     ]
    //
    // This could be written more simply using [List.map], but we want to avoid
    // any allocations in the common case where no extends apply.
    List<List<ComplexSelector>>? extendedNotExpanded;
    var isOriginal = _originals.contains(complex);
    for (var i = 0; i < complex.components.length; i++) {
      var component = complex.components[i];
      var extended = _extendCompound(component, extensions, mediaQueryContext,
          inOriginal: isOriginal);
      assert(
          extended?.isNotEmpty ?? true,
          '_extendCompound($component) should return null rather than [] if '
          'extension fails');
      if (extended == null) {
        extendedNotExpanded?.add([
          ComplexSelector(const [], [component], complex.span,
              lineBreak: complex.lineBreak)
        ]);
      } else if (extendedNotExpanded != null) {
        extendedNotExpanded.add(extended);
      } else if (i != 0) {
        extendedNotExpanded = [
          [
            ComplexSelector(complex.leadingCombinators,
                complex.components.take(i), complex.span,
                lineBreak: complex.lineBreak)
          ],
          extended
        ];
      } else if (complex.leadingCombinators.isEmpty) {
        extendedNotExpanded = [extended];
      } else {
        extendedNotExpanded = [
          [
            for (var newComplex in extended)
              if (newComplex.leadingCombinators.isEmpty ||
                  listEquals(complex.leadingCombinators,
                      newComplex.leadingCombinators))
                ComplexSelector(complex.leadingCombinators,
                    newComplex.components, complex.span,
                    lineBreak: complex.lineBreak || newComplex.lineBreak)
          ]
        ];
      }
    }
    if (extendedNotExpanded == null) return null;

    var first = true;
    return paths(extendedNotExpanded).expand((path) {
      return weave(path, complex.span, forceLineBreak: complex.lineBreak)
          .map((outputComplex) {
        // Make sure that copies of [complex] retain their status as "original"
        // selectors. This includes selectors that are modified because a :not()
        // was extended into.
        if (first && _originals.contains(complex)) {
          _originals.add(outputComplex);
        }
        first = false;

        return outputComplex;
      });
    }).toList();
  }

  /// Extends [component] using [extensions], and returns the contents of a
  /// [SelectorList].
  ///
  /// The [inOriginal] parameter indicates whether this is in an original
  /// complex selector, meaning that [compound] should not be trimmed out.
  ///
  /// The [lineBreak] parameter indicates whether [component] appears in a
  /// complex selector with a line break.
  List<ComplexSelector>? _extendCompound(
      ComplexSelectorComponent component,
      Map<SimpleSelector, Map<ComplexSelector, Extension>> extensions,
      List<CssMediaQuery>? mediaQueryContext,
      {required bool inOriginal}) {
    // If there's more than one target and they all need to match, we track
    // which targets are actually extended.
    var targetsUsed = _mode == ExtendMode.normal || extensions.length < 2
        ? null
        : <SimpleSelector>{};

    var simples = component.selector.components;

    // The complex selectors produced from each simple selector in [compound].
    List<List<Extender>>? options;
    for (var i = 0; i < simples.length; i++) {
      var simple = simples[i];
      var extended =
          _extendSimple(simple, extensions, mediaQueryContext, targetsUsed);
      assert(
          extended?.isNotEmpty ?? true,
          '_extendSimple($simple) should return null rather than [] if '
          'extension fails');
      if (extended == null) {
        options?.add([_extenderForSimple(simple)]);
      } else {
        if (options == null) {
          options = [];
          if (i != 0) {
            options
                .add([_extenderForCompound(simples.take(i), component.span)]);
          }
        }

        options.addAll(extended);
      }
    }
    if (options == null) return null;

    // If [_mode] isn't [ExtendMode.normal] and we didn't use all the targets in
    // [extensions], extension fails for [component].
    if (targetsUsed != null && targetsUsed.length != extensions.length) {
      return null;
    }

    // Optimize for the simple case of a single simple selector that doesn't
    // need any unification.
    if (options case [var extenders]) {
      List<ComplexSelector>? result;
      for (var extender in extenders) {
        extender.assertCompatibleMediaContext(mediaQueryContext);
        var complex =
            extender.selector.withAdditionalCombinators(component.combinators);
        if (complex.isUseless) continue;
        result ??= [];
        result.add(complex);
      }
      return result;
    }

    // Find all paths through [options]. In this case, each path represents a
    // different unification of the base selector. For example, if we have:
    //
    //     .a.b {...}
    //     .w .x {@extend .a}
    //     .y .z {@extend .b}
    //
    // then [options] is `[[.a, .w .x], [.b, .y .z]]` and `paths(options)` is
    //
    //     [
    //       [.a, .b],
    //       [.a, .y .z],
    //       [.w .x, .b],
    //       [.w .x, .y .z]
    //     ]
    //
    // We then unify each path to get a list of complex selectors:
    //
    //     [
    //       [.a.b],
    //       [.y .a.z],
    //       [.w .x.b],
    //       [.w .y .x.z, .y .w .x.z]
    //     ]
    //
    // And finally flatten them to get:
    //
    //     [
    //       .a.b,
    //       .y .a.z,
    //       .w .x.b,
    //       .w .y .x.z,
    //       .y .w .x.z
    //     ]
    var extenderPaths = paths(options);
    var result = [
      if (_mode != ExtendMode.replace)
        // The first path is always the original selector. We can't just return
        // [component] directly because selector pseudos may be modified, but we
        // don't have to do any unification.
        ComplexSelector(const [], [
          ComplexSelectorComponent(
              CompoundSelector(extenderPaths.first.expand((extender) {
                assert(extender.selector.components.length == 1);
                return extender.selector.components.last.selector.components;
              }), component.selector.span),
              component.combinators,
              component.span)
        ], component.span)
    ];

    for (var path in extenderPaths.skip(_mode == ExtendMode.replace ? 0 : 1)) {
      var extended = _unifyExtenders(path, mediaQueryContext, component.span);
      if (extended == null) continue;

      for (var complex in extended) {
        var withCombinators =
            complex.withAdditionalCombinators(component.combinators);
        if (!withCombinators.isUseless) result.add(withCombinators);
      }
    }

    // If we're preserving the original selector, mark the first unification as
    // such so [_trim] doesn't get rid of it.
    var isOriginal = (ComplexSelector _) => false;
    if (inOriginal && _mode != ExtendMode.replace) {
      var original = result.first;
      isOriginal = (complex) => complex == original;
    }

    return _trim(result, isOriginal);
  }

  /// Returns a list of [ComplexSelector]s that match the intersection of
  /// elements matched by all of [extenders]' selectors.
  ///
  /// The [span] will be used for the new selectors.
  List<ComplexSelector>? _unifyExtenders(List<Extender> extenders,
      List<CssMediaQuery>? mediaQueryContext, FileSpan span) {
    var toUnify = QueueList<ComplexSelector>();
    List<SimpleSelector>? originals;
    var originalsLineBreak = false;
    for (var extender in extenders) {
      if (extender.isOriginal) {
        originals ??= [];
        var finalExtenderComponent = extender.selector.components.last;
        assert(finalExtenderComponent.combinators.isEmpty);
        originals.addAll(finalExtenderComponent.selector.components);
        originalsLineBreak = originalsLineBreak || extender.selector.lineBreak;
      } else if (extender.selector.isUseless) {
        return null;
      } else {
        toUnify.add(extender.selector);
      }
    }

    if (originals != null) {
      toUnify.addFirst(ComplexSelector(const [], [
        ComplexSelectorComponent(
            CompoundSelector(originals, span), const [], span)
      ], span, lineBreak: originalsLineBreak));
    }

    var complexes = unifyComplex(toUnify, span);
    if (complexes == null) return null;

    for (var extender in extenders) {
      extender.assertCompatibleMediaContext(mediaQueryContext);
    }

    return complexes;
  }

  /// Returns the [Extender]s from [extensions] that that should replace
  /// [simple], or `null` if it's not the target of an extension.
  ///
  /// Each element of the returned iterable is a list of choices, which will be
  /// combined using [paths].
  Iterable<List<Extender>>? _extendSimple(
      SimpleSelector simple,
      Map<SimpleSelector, Map<ComplexSelector, Extension>> extensions,
      List<CssMediaQuery>? mediaQueryContext,
      Set<SimpleSelector>? targetsUsed) {
    // Extends [simple] without extending the contents of any selector pseudos
    // it contains.
    List<Extender>? withoutPseudo(SimpleSelector simple) {
      var extensionsForSimple = extensions[simple];
      if (extensionsForSimple == null) return null;
      targetsUsed?.add(simple);

      return [
        if (_mode != ExtendMode.replace) _extenderForSimple(simple),
        for (var extension in extensionsForSimple.values) extension.extender
      ];
    }

    if (simple case PseudoSelector(selector: _?)) {
      if (_extendPseudo(simple, extensions, mediaQueryContext)
          case var extended?) {
        return extended.map(
            (pseudo) => withoutPseudo(pseudo) ?? [_extenderForSimple(pseudo)]);
      }
    }

    return withoutPseudo(simple).andThen((result) => [result]);
  }

  /// Returns an [Extender] composed solely of a compound selector containing
  /// [simples].
  Extender _extenderForCompound(
      Iterable<SimpleSelector> simples, FileSpan span) {
    var compound = CompoundSelector(simples, span);
    return Extender(
        ComplexSelector(const [],
            [ComplexSelectorComponent(compound, const [], span)], span),
        specificity: _sourceSpecificityFor(compound),
        original: true);
  }

  /// Returns an [Extender] composed solely of [simple].
  Extender _extenderForSimple(SimpleSelector simple) => Extender(
      ComplexSelector(const [], [
        ComplexSelectorComponent(
            CompoundSelector([simple], simple.span), const [], simple.span)
      ], simple.span),
      specificity: _sourceSpecificity[simple] ?? 0,
      original: true);

  /// Extends [pseudo] using [extensions], and returns a list of resulting
  /// pseudo selectors.
  ///
  /// This requires that [pseudo] have a selector argument.
  List<PseudoSelector>? _extendPseudo(
      PseudoSelector pseudo,
      Map<SimpleSelector, Map<ComplexSelector, Extension>> extensions,
      List<CssMediaQuery>? mediaQueryContext) {
    var selector = pseudo.selector;
    if (selector == null) {
      throw ArgumentError("Selector $pseudo must have a selector argument.");
    }

    var extended = _extendList(selector, extensions, mediaQueryContext);
    if (identical(extended, selector)) return null;

    // For `:not()`, we usually want to get rid of any complex selectors because
    // that will cause the selector to fail to parse on all browsers at time of
    // writing. We can keep them if either the original selector had a complex
    // selector, or the result of extending has only complex selectors, because
    // either way we aren't breaking anything that isn't already broken.
    Iterable<ComplexSelector> complexes = extended.components;
    if (pseudo.normalizedName == "not" &&
        !selector.components.any((complex) => complex.components.length > 1) &&
        extended.components.any((complex) => complex.components.length == 1)) {
      complexes = extended.components
          .where((complex) => complex.components.length <= 1);
    }

    complexes = complexes.expand((complex) {
      var innerPseudo = complex.singleCompound?.singleSimple;
      if (innerPseudo is! PseudoSelector) return [complex];
      var innerSelector = innerPseudo.selector;
      if (innerSelector == null) return [complex];

      switch (pseudo.normalizedName) {
        case 'not':
          // In theory, if there's a `:not` nested within another `:not`, the
          // inner `:not`'s contents should be unified with the return value.
          // For example, if `:not(.foo)` extends `.bar`, `:not(.bar)` should
          // become `.foo:not(.bar)`. However, this is a narrow edge case and
          // supporting it properly would make this code and the code calling it
          // a lot more complicated, so it's not supported for now.
          if (!const {'is', 'matches', 'where'}
              .contains(innerPseudo.normalizedName)) {
            return [];
          }
          return innerSelector.components;

        case 'is':
        case 'matches':
        case 'where':
        case 'any':
        case 'current':
        case 'nth-child':
        case 'nth-last-child':
          // As above, we could theoretically support :not within :matches, but
          // doing so would require this method and its callers to handle much
          // more complex cases that likely aren't worth the pain.
          if (innerPseudo.name != pseudo.name) return [];
          if (innerPseudo.argument != pseudo.argument) return [];
          return innerSelector.components;

        case 'has':
        case 'host':
        case 'host-context':
        case 'slotted':
          // We can't expand nested selectors here, because each layer adds an
          // additional layer of semantics. For example, `:has(:has(img))`
          // doesn't match `<div><img></div>` but `:has(img)` does.
          return [complex];

        default:
          return [];
      }
    });

    // Older browsers support `:not`, but only with a single complex selector.
    // In order to support those browsers, we break up the contents of a `:not`
    // unless it originally contained a selector list.
    if (pseudo.normalizedName == 'not' && selector.components.length == 1) {
      var result = complexes
          .map((complex) =>
              pseudo.withSelector(SelectorList([complex], selector.span)))
          .toList();
      return result.isEmpty ? null : result;
    } else {
      return [pseudo.withSelector(SelectorList(complexes, selector.span))];
    }
  }

  // Removes elements from [selectors] if they're subselectors of other
  // elements.
  //
  // The [isOriginal] callback indicates which selectors are original to the
  // document, and thus should never be trimmed.
  List<ComplexSelector> _trim(List<ComplexSelector> selectors,
      bool isOriginal(ComplexSelector complex)) {
    // Avoid truly horrific quadratic behavior.
    //
    // TODO(nweiz): I think there may be a way to get perfect trimming without
    // going quadratic by building some sort of trie-like data structure that
    // can be used to look up superselectors.
    if (selectors.length > 100) return selectors;

    // This is n² on the sequences, but only comparing between separate
    // sequences should limit the quadratic behavior. We iterate from last to
    // first and reverse the result so that, if two selectors are identical, we
    // keep the first one.
    var result = QueueList<ComplexSelector>();
    var numOriginals = 0;
    outer:
    for (var i = selectors.length - 1; i >= 0; i--) {
      var complex1 = selectors[i];
      if (isOriginal(complex1)) {
        // Make sure we don't include duplicate originals, which could happen if
        // a style rule extends a component of its own selector.
        for (var j = 0; j < numOriginals; j++) {
          if (result[j] == complex1) {
            rotateSlice(result, 0, j + 1);
            continue outer;
          }
        }

        numOriginals++;
        result.addFirst(complex1);
        continue;
      }

      // The maximum specificity of the sources that caused [complex1] to be
      // generated. In order for [complex1] to be removed, there must be another
      // selector that's a superselector of it *and* that has specificity
      // greater or equal to this.
      var maxSpecificity = 0;
      for (var component in complex1.components) {
        maxSpecificity =
            math.max(maxSpecificity, _sourceSpecificityFor(component.selector));
      }

      // Look in [result] rather than [selectors] for selectors after [i]. This
      // ensures that we aren't comparing against a selector that's already been
      // trimmed, and thus that if there are two identical selectors only one is
      // trimmed.
      if (result.any((complex2) =>
          complex2.specificity >= maxSpecificity &&
          complex2.isSuperselector(complex1))) {
        continue;
      }

      if (selectors.take(i).any((complex2) =>
          complex2.specificity >= maxSpecificity &&
          complex2.isSuperselector(complex1))) {
        continue;
      }

      result.addFirst(complex1);
    }
    return result;
  }

  /// Returns the maximum specificity for sources that went into producing
  /// [compound].
  int _sourceSpecificityFor(CompoundSelector compound) {
    var specificity = 0;
    for (var simple in compound.components) {
      specificity = math.max(specificity, _sourceSpecificity[simple] ?? 0);
    }
    return specificity;
  }

  /// Returns a copy of `this` that extends new selectors, as well as a map
  /// (with reference equality) from the selectors extended by `this` to the
  /// selectors extended by the new [ExtensionStore].
  (ExtensionStore, Map<SelectorList, Box<SelectorList>>) clone() {
    var newSelectors = <SimpleSelector, Set<ModifiableBox<SelectorList>>>{};
    var newMediaContexts = <ModifiableBox<SelectorList>, List<CssMediaQuery>>{};
    var oldToNewSelectors = Map<SelectorList, Box<SelectorList>>.identity();

    _selectors.forEach((simple, selectors) {
      var newSelectorSet = <ModifiableBox<SelectorList>>{};
      newSelectors[simple] = newSelectorSet;

      for (var selector in selectors) {
        var newSelector = ModifiableBox(selector.value);
        newSelectorSet.add(newSelector);
        oldToNewSelectors[selector.value] = newSelector.seal();

        if (_mediaContexts[selector] case var mediaContext?) {
          newMediaContexts[newSelector] = mediaContext;
        }
      }
    });

    return (
      ExtensionStore._(
          newSelectors,
          copyMapOfMap(_extensions),
          copyMapOfList(_extensionsByExtender),
          newMediaContexts,
          Map.identity()..addAll(_sourceSpecificity),
          Set.identity()..addAll(_originals)),
      oldToNewSelectors
    );
  }
}
