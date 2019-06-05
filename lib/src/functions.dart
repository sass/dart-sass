// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';

import 'callable.dart';
import 'functions/color.dart' as color;
import 'functions/list.dart' as list;
import 'functions/map.dart' as map;
import 'functions/math.dart' as math;
import 'functions/meta.dart' as meta;
import 'functions/selector.dart' as selector;
import 'functions/string.dart' as string;

/// Sass core functions that are globally available.
///
/// This excludes a few functions that need access to the evaluation context;
/// these are defined in `_EvaluateVisitor`.
final List<BuiltInCallable> globalFunctions = UnmodifiableListView([
  ...color.global,
  ...list.global,
  ...map.global,
  ...math.global,
  ...selector.global,
  ...string.global,
  ...meta.global,

  // This is only invoked using `call()`. Hand-authored `if()`s are parsed as
  // [IfExpression]s.
  BuiltInCallable("if", r"$condition, $if-true, $if-false",
      (arguments) => arguments[0].isTruthy ? arguments[1] : arguments[2]),
]);

/// Sass's core library modules.
///
/// This doesn't include the `meta` module, because that needs additional
/// functions that can only be defined in the evaluator itself.
final coreModules = UnmodifiableListView([
  color.module,
  list.module,
  map.module,
  math.module,
  selector.module,
  string.module
]);
