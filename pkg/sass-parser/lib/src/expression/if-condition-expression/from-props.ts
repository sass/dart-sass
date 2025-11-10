// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {AnyIfConditionExpression, IfConditionExpressionProps} from '.';
import {IfConditionSass} from './sass';

/** Constructs an expression from {@link ExpressionProps}. */
export function fromProps(
  props: IfConditionExpressionProps,
): AnyIfConditionExpression {
  return new IfConditionSass(props);
}
