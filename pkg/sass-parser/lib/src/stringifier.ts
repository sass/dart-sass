// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// Portions of this source file are adapted from the PostCSS codebase under the
// terms of the following license:
//
// The MIT License (MIT)
//
// Copyright 2013 Andrey Sitnik <andrey@sitnik.ru>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import * as postcss from 'postcss';

import {AnyStatement} from './statement';
import {DebugRule} from './statement/debug-rule';
import {EachRule} from './statement/each-rule';
import {GenericAtRule} from './statement/generic-at-rule';
import {Rule} from './statement/rule';

const PostCssStringifier = require('postcss/lib/stringifier');

/**
 * A visitor that stringifies Sass statements.
 *
 * Expression-level nodes are handled differently because they don't need to
 * integrate into PostCSS's source map infratructure.
 */
export class Stringifier extends PostCssStringifier {
  constructor(builder: postcss.Builder) {
    super(builder);
  }

  /** Converts `node` into a string by calling {@link this.builder}. */
  stringify(node: postcss.AnyNode, semicolon: boolean): void {
    if (!('sassType' in node)) {
      postcss.stringify(node, this.builder);
      return;
    }

    const statement = node as AnyStatement;
    if (!this[statement.sassType]) {
      throw new Error(
        `Unknown AST node type ${statement.sassType}. ` +
          'Maybe you need to change PostCSS stringifier.'
      );
    }
    (
      this[statement.sassType] as (
        node: AnyStatement,
        semicolon: boolean
      ) => void
    )(statement, semicolon);
  }

  private ['debug-rule'](node: DebugRule, semicolon: boolean): void {
    this.builder(
      '@debug' +
        (node.raws.afterName ?? ' ') +
        node.debugExpression +
        (node.raws.between ?? '') +
        (semicolon ? ';' : ''),
      node
    );
  }

  private ['each-rule'](node: EachRule): void {
    this.block(
      node,
      '@each' +
        (node.raws.afterName ?? ' ') +
        node.params +
        (node.raws.between ?? '')
    );
  }

  private atrule(node: GenericAtRule, semicolon: boolean): void {
    // In the @at-root shorthand, stringify `@at-root {.foo {...}}` as
    // `@at-root .foo {...}`.
    if (
      node.raws.atRootShorthand &&
      node.name === 'at-root' &&
      node.paramsInterpolation === undefined &&
      node.nodes.length === 1 &&
      node.nodes[0].sassType === 'rule'
    ) {
      this.block(
        node.nodes[0],
        '@at-root' +
          (node.raws.afterName ?? ' ') +
          node.nodes[0].selectorInterpolation
      );
      return;
    }

    const start =
      `@${node.nameInterpolation}` +
      (node.raws.afterName ?? (node.paramsInterpolation ? ' ' : '')) +
      (node.paramsInterpolation ?? '');
    if (node.nodes) {
      this.block(node, start);
    } else {
      this.builder(
        start + (node.raws.between ?? '') + (semicolon ? ';' : ''),
        node
      );
    }
  }

  private rule(node: Rule): void {
    this.block(node, node.selectorInterpolation.toString());
  }
}
