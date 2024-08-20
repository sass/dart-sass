// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Node, NodeProps} from '../node';
import * as sassInternal from '../sass-internal';
import {GenericAtRule, GenericAtRuleProps} from './generic-at-rule';
import {Root} from './root';
import {Rule, RuleProps} from './rule';

// TODO: Replace this with the corresponding Sass types once they're
// implemented.
export {Comment, Declaration} from 'postcss';

/**
 * The union type of all Sass statements.
 *
 * @category Statement
 */
export type AnyStatement = Root | Rule | GenericAtRule;

/**
 * Sass statement types.
 *
 * This is a superset of the node types PostCSS exposes, and is provided
 * alongside `Node.type` to disambiguate between the wide range of statements
 * that Sass parses as distinct types.
 *
 * @category Statement
 */
export type StatementType = 'root' | 'rule' | 'atrule';

/**
 * All Sass statements that are also at-rules.
 *
 * @category Statement
 */
export type AtRule = GenericAtRule;

/**
 * All Sass statements that are valid children of other statements.
 *
 * The Sass equivalent of PostCSS's `ChildNode`.
 *
 * @category Statement
 */
export type ChildNode = Rule | AtRule;

/**
 * The properties that can be used to construct {@link ChildNode}s.
 *
 * The Sass equivalent of PostCSS's `ChildProps`.
 *
 * @category Statement
 */
export type ChildProps = postcss.ChildProps | RuleProps | GenericAtRuleProps;

/**
 * The Sass eqivalent of PostCSS's `ContainerProps`.
 *
 * @category Statement
 */
export interface ContainerProps extends NodeProps {
  nodes?: (postcss.Node | ChildProps)[];
}

/**
 * A {@link Statement} that has actual child nodes.
 *
 * @category Statement
 */
export type StatementWithChildren = postcss.Container<ChildNode> & {
  nodes: ChildNode[];
} & Statement;

/**
 * A statement in a Sass stylesheet.
 *
 * In addition to implementing the standard PostCSS behavior, this provides
 * extra information to help disambiguate different types that Sass parses
 * differently.
 *
 * @category Statement
 */
export interface Statement extends postcss.Node, Node {
  /** The type of this statement. */
  readonly sassType: StatementType;

  parent: StatementWithChildren | undefined;
}

/** The visitor to use to convert internal Sass nodes to JS. */
const visitor = sassInternal.createStatementVisitor<Statement>({
  visitAtRule: inner => new GenericAtRule(undefined, inner),
  visitStyleRule: inner => new Rule(undefined, inner),
});

/** Appends parsed versions of `internal`'s children to `container`. */
export function appendInternalChildren(
  container: postcss.Container,
  children: sassInternal.Statement[] | null
): void {
  // Make sure `container` knows it has a block.
  if (children?.length === 0) container.append(undefined);
  if (!children) return;
  for (const child of children) {
    container.append(child.accept(visitor));
  }
}

/**
 * The type of nodes that can be passed as new child nodes to PostCSS methods.
 */
export type NewNode =
  | ChildProps
  | ReadonlyArray<ChildProps>
  | postcss.Node
  | ReadonlyArray<postcss.Node>
  | string
  | ReadonlyArray<string>
  | undefined;

/** PostCSS's built-in normalize function. */
const postcssNormalize = postcss.Container.prototype.normalize;

/**
 * A wrapper around {@link postcssNormalize} that converts the results to the
 * corresponding Sass type(s) after normalizing.
 */
function postcssNormalizeAndConvertToSass(
  self: StatementWithChildren,
  node: string | postcss.ChildProps | postcss.Node,
  sample: postcss.Node | undefined
): ChildNode[] {
  return postcssNormalize.call(self, node, sample).map(postcssNode => {
    // postcssNormalize sets the parent to the Sass node, but we don't want to
    // mix Sass AST nodes with plain PostCSS AST nodes so we unset it in favor
    // of creating a totally new node.
    postcssNode.parent = undefined;

    switch (postcssNode.type) {
      case 'atrule':
        return new GenericAtRule({
          name: postcssNode.name,
          params: postcssNode.params,
          raws: postcssNode.raws,
          source: postcssNode.source,
        });
      case 'rule':
        return new Rule({
          selector: postcssNode.selector,
          raws: postcssNode.raws,
          source: postcssNode.source,
        });
      default:
        throw new Error(`Unsupported PostCSS node type ${postcssNode.type}`);
    }
  });
}

/**
 * An override of {@link postcssNormalize} that supports Sass nodes as arguments
 * and converts PostCSS-style arguments to Sass.
 */
export function normalize(
  self: StatementWithChildren,
  node: NewNode,
  sample?: postcss.Node
): ChildNode[] {
  if (node === undefined) return [];
  const nodes = Array.isArray(node) ? node : [node];

  const result: ChildNode[] = [];
  for (const node of nodes) {
    if (typeof node === 'string') {
      // We could in principle parse these as Sass.
      result.push(...postcssNormalizeAndConvertToSass(self, node, sample));
    } else if ('sassType' in node) {
      if (node.sassType === 'root') {
        result.push(...(node as Root).nodes);
      } else {
        result.push(node as ChildNode);
      }
    } else if ('type' in node) {
      result.push(...postcssNormalizeAndConvertToSass(self, node, sample));
    } else if (
      'selectorInterpolation' in node ||
      'selector' in node ||
      'selectors' in node
    ) {
      result.push(new Rule(node));
    } else if ('name' in node || 'nameInterpolation' in node) {
      result.push(new GenericAtRule(node));
    } else {
      result.push(...postcssNormalizeAndConvertToSass(self, node, sample));
    }
  }

  for (const node of result) {
    if (node.parent) node.parent.removeChild(node);
    if (
      node.raws.before === 'undefined' &&
      sample?.raws?.before !== undefined
    ) {
      node.raws.before = sample.raws.before.replace(/\S/g, '');
    }
    node.parent = self;
  }

  return result;
}
