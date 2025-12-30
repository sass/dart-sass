// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {AnyIfConditionExpression, IfConditionExpressionProps} from '.';
import {IfConditionFunction} from './function';
import {IfConditionNegation} from './negation';
import {IfConditionOperation} from './operation';
import {IfConditionParenthesized} from './parenthesized';
import {IfConditionRaw} from './raw';
import {IfConditionSass} from './sass';

/**
 * Constructs a condition from {@link IfConditionexpressionProps}, or returns an
 * existing condition as-is.
 */
export function fromProps(
  props: AnyIfConditionExpression | IfConditionExpressionProps,
): AnyIfConditionExpression {
  if ('sassType' in props) {
    const sassType = props.sassType;
    if (
      sassType === 'if-condition-function' ||
      sassType === 'if-condition-negation' ||
      sassType === 'if-condition-operation' ||
      sassType === 'if-condition-parenthesized' ||
      sassType === 'if-condition-raw' ||
      sassType === 'if-condition-sass'
    ) {
      return props;
    } else {
      return new IfConditionSass(props);
    }
  } else if ('argument' in props) {
    return new IfConditionFunction(props);
  } else if ('negated' in props) {
    return new IfConditionNegation(props);
  } else if ('operator' in props && 'nodes' in props) {
    return new IfConditionOperation(props);
  } else if ('parenthesized' in props) {
    return new IfConditionParenthesized(props);
  } else if ('rawInterpolation' in props) {
    return new IfConditionRaw(props);
  } else {
    return new IfConditionSass(props);
  }
}
