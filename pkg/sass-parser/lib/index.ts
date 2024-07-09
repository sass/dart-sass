// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import * as sassApi from 'sass';

import {Root} from './src/statement/root';
import * as sassInternal from './src/sass-internal';
import {Stringifier} from './src/stringifier';

export {AnyNode, Node, NodeProps, NodeType} from './src/node';
export {
  AnyExpression,
  Expression,
  ExpressionProps,
  ExpressionType,
} from './src/expression';
export {
  BinaryOperationExpression,
  BinaryOperationExpressionProps,
  BinaryOperationExpressionRaws,
  BinaryOperator,
} from './src/expression/binary-operation';
export {
  StringExpression,
  StringExpressionProps,
  StringExpressionRaws,
} from './src/expression/string';
export {
  Interpolation,
  InterpolationProps,
  InterpolationRaws,
  NewNodeForInterpolation,
} from './src/interpolation';
export {
  GenericAtRule,
  GenericAtRuleProps,
  GenericAtRuleRaws,
} from './src/statement/generic-at-rule';
export {Root, RootProps, RootRaws} from './src/statement/root';
export {Rule} from './src/statement/rule';
export {
  AnyStatement,
  ChildNode,
  ChildProps,
  ContainerProps,
  Statement,
  StatementType,
} from './src/statement';

/** Options that can be passed to the Sass parsers to control their behavior. */
export interface SassParserOptions
  extends Pick<postcss.ProcessOptions, 'from' | 'map'> {
  /** The logger that's used to log messages encountered during parsing. */
  logger?: sassApi.Logger;
}

/** A PostCSS syntax for parsing a particular Sass syntax. */
class Syntax implements postcss.Syntax<postcss.Root> {
  /** The syntax with which to parse stylesheets. */
  readonly #syntax: sassInternal.Syntax;

  constructor(syntax: sassInternal.Syntax) {
    this.#syntax = syntax;
  }

  parse(css: {toString(): string} | string, opts?: SassParserOptions): Root {
    if (opts?.map) {
      // We might be able to support this as a layer on top of source spans, but
      // is it worth the effort?
      throw "sass-parser doesn't currently support consuming source maps.";
    }

    return new Root(
      undefined,
      sassInternal.parse(css.toString(), this.#syntax, opts?.from, opts?.logger)
    );
  }

  stringify(node: postcss.AnyNode, builder: postcss.Builder): void {
    new Stringifier(builder).stringify(node, true);
  }
}

/** A PostCSS syntax for parsing SCSS. */
export const scss = new Syntax('scss');

/** A PostCSS syntax for parsing Sass's indented syntax. */
export const sass = new Syntax('sass');

/** A PostCSS syntax for parsing plain CSS. */
export const css = new Syntax('css');
