// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as sassInternal from '../sass-internal';

import {ArgumentList} from '../argument-list';
import {Interpolation} from '../interpolation';
import {LazySource} from '../lazy-source';
import {AnyExpression} from '.';
import {BinaryOperationExpression} from './binary-operation';
import {BooleanExpression} from './boolean';
import {ColorExpression} from './color';
import {FunctionExpression} from './function';
import {InterpolatedFunctionExpression} from './interpolated-function';
import {ListExpression} from './list';
import {MapExpression} from './map';
import {NullExpression} from './null';
import {NumberExpression} from './number';
import {ParenthesizedExpression} from './parenthesized';
import {SelectorExpression} from './selector';
import {StringExpression} from './string';

/** The visitor to use to convert internal Sass nodes to JS. */
const visitor = sassInternal.createExpressionVisitor<AnyExpression>({
  visitBinaryOperationExpression: inner =>
    new BinaryOperationExpression(undefined, inner),
  visitBooleanExpression: inner => new BooleanExpression(undefined, inner),
  visitColorExpression: inner => new ColorExpression(undefined, inner),
  visitFunctionExpression: inner => new FunctionExpression(undefined, inner),
  visitIfExpression: inner =>
    new FunctionExpression({
      name: 'if',
      arguments: new ArgumentList(undefined, inner.arguments),
    }),
  visitInterpolatedFunctionExpression: inner =>
    new InterpolatedFunctionExpression(undefined, inner),
  visitListExpression: inner => new ListExpression(undefined, inner),
  visitMapExpression: inner => new MapExpression(undefined, inner),
  visitNullExpression: inner => new NullExpression(undefined, inner),
  visitNumberExpression: inner => new NumberExpression(undefined, inner),
  visitParenthesizedExpression: inner =>
    new ParenthesizedExpression(undefined, inner),
  visitSelectorExpression: inner => new SelectorExpression(undefined, inner),
  visitStringExpression: inner => new StringExpression(undefined, inner),
  visitSupportsExpression: inner =>
    new StringExpression({
      text: new Interpolation([
        '(',
        new Interpolation(undefined, inner.condition.toInterpolation()),
        ')',
      ]),
      source: new LazySource(inner),
    }),
});

/** Converts an internal expression AST node into an external one. */
export function convertExpression(
  expression: sassInternal.Expression,
): AnyExpression {
  return expression.accept(visitor);
}
