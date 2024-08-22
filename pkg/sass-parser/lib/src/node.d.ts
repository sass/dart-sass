// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {AnyExpression, ExpressionType} from './expression';
import {Interpolation} from './interpolation';
import {AnyStatement, Statement, StatementType} from './statement';

/** The union type of all Sass nodes. */
export type AnyNode = AnyStatement | AnyExpression | Interpolation;

/**
 * All Sass node types.
 *
 * This is a superset of the node types PostCSS exposes, and is provided
 * alongside `Node.type` to disambiguate between the wide range of nodes that
 * Sass parses as distinct types.
 */
export type NodeType = StatementType | ExpressionType | 'interpolation';

/** The constructor properties shared by all Sass AST nodes. */
export type NodeProps = postcss.NodeProps;

/**
 * Any node in a Sass stylesheet.
 *
 * All nodes that Sass can parse implement this type, including expression-level
 * nodes, selector nodes, and nodes from more domain-specific syntaxes. It aims
 * to match the PostCSS API as closely as possible while still being generic
 * enough to work across multiple more than just statements.
 *
 * This does _not_ include methods for adding and modifying siblings of this
 * Node, because these only make sense for expression-level Node types.
 */
declare abstract class Node
  implements
    Omit<
      postcss.Node,
      | 'after'
      | 'assign'
      | 'before'
      | 'clone'
      | 'cloneAfter'
      | 'cloneBefore'
      | 'next'
      | 'prev'
      | 'remove'
      // TODO: supporting replaceWith() would be tricky, but it does have
      // well-defined semantics even without a nodes array and it's awfully
      // useful. See if we can find a way.
      | 'replaceWith'
      | 'type'
      | 'parent'
      | 'toString'
    >
{
  abstract readonly sassType: NodeType;
  parent: Node | undefined;
  source?: postcss.Source;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  raws: any;

  /**
   * A list of children of this node, *not* including any {@link Statement}s it
   * contains. This is used internally to traverse the full AST.
   *
   * @hidden
   */
  abstract get nonStatementChildren(): ReadonlyArray<Exclude<Node, Statement>>;

  constructor(defaults?: object);

  assign(overrides: object): this;
  cleanRaws(keepBetween?: boolean): void;
  error(
    message: string,
    options?: postcss.NodeErrorOptions
  ): postcss.CssSyntaxError;
  positionBy(
    opts?: Pick<postcss.WarningOptions, 'index' | 'word'>
  ): postcss.Position;
  positionInside(index: number): postcss.Position;
  rangeBy(opts?: Pick<postcss.WarningOptions, 'endIndex' | 'index' | 'word'>): {
    start: postcss.Position;
    end: postcss.Position;
  };
  raw(prop: string, defaultType?: string): string;
  root(): postcss.Root;
  toJSON(): object;
  warn(
    result: postcss.Result,
    message: string,
    options?: postcss.WarningOptions
  ): postcss.Warning;
}
