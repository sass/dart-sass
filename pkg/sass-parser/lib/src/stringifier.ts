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
import {Declaration} from './statement/declaration';
import {EachRule} from './statement/each-rule';
import {ElseRule} from './statement/else-rule';
import {ErrorRule} from './statement/error-rule';
import {ForRule} from './statement/for-rule';
import {ForwardRule} from './statement/forward-rule';
import {FunctionRule} from './statement/function-rule';
import {GenericAtRule} from './statement/generic-at-rule';
import {IfRule} from './statement/if-rule';
import {IncludeRule} from './statement/include-rule';
import {MixinRule} from './statement/mixin-rule';
import {ReturnRule} from './statement/return-rule';
import {Rule} from './statement/rule';
import {SassComment} from './statement/sass-comment';
import {UseRule} from './statement/use-rule';
import {VariableDeclaration} from './statement/variable-declaration';
import {WarnRule} from './statement/warn-rule';
import {WhileRule} from './statement/while-rule';

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
          'Maybe you need to change PostCSS stringifier.',
      );
    }
    (
      this[statement.sassType] as (
        node: AnyStatement,
        semicolon: boolean,
      ) => void
    )(statement, semicolon);
  }

  private ['debug-rule'](node: DebugRule, semicolon: boolean): void {
    this.sassAtRule(node, semicolon);
  }

  decl(node: Declaration, semicolon: boolean): void {
    const start =
      node.propInterpolation.toString() +
      (node.raws.between ?? (node.expression ? ': ' : ':')) +
      (node.expression ? node.expression : '');

    // We can't use Stringifier.block() here because it expects the "between"
    // raw to refer to the whitespace immediately before `{`, but for a
    // declaration (even one with children) it refers to `: ` instead.
    if (node.nodes) {
      this.builder(start + (node.raws.afterValue ?? ' ') + '{');

      let after;
      if (node.nodes.length) {
        this.body(node);
        after = this.raw(node, 'after');
      } else {
        after = this.raw(node, 'after', 'emptyBody');
      }

      if (after) this.builder(after);
      this.builder('}', node, 'end');
      if (node.raws.ownSemicolon) {
        this.builder(node.raws.ownSemicolon, node, 'end');
      }
    } else {
      this.builder(
        start + (node.raws.afterValue ?? '') + (semicolon ? ';' : ''),
      );
    }
  }

  private ['each-rule'](node: EachRule): void {
    this.sassAtRule(node);
  }

  private ['else-rule'](node: ElseRule): void {
    this.sassAtRule(node);
  }

  private ['error-rule'](node: ErrorRule, semicolon: boolean): void {
    this.sassAtRule(node, semicolon);
  }

  private ['for-rule'](node: ForRule): void {
    this.sassAtRule(node);
  }

  private ['forward-rule'](node: ForwardRule, semicolon: boolean): void {
    this.sassAtRule(node, semicolon);
  }

  private ['function-rule'](node: FunctionRule, semicolon: boolean): void {
    this.sassAtRule(node, semicolon);
  }

  private ['if-rule'](node: IfRule): void {
    this.sassAtRule(node);
  }

  private ['include-rule'](node: IncludeRule, semicolon: boolean): void {
    this.sassAtRule(node, semicolon);
  }

  private ['mixin-rule'](node: MixinRule, semicolon: boolean): void {
    this.sassAtRule(node, semicolon);
  }

  private atrule(node: GenericAtRule, semicolon: boolean): void {
    // In the @at-root shorthand, stringify `@at-root {.foo {...}}` as
    // `@at-root .foo {...}`.
    if (
      node.raws.atRootShorthand &&
      node.name === 'at-root' &&
      node.paramsInterpolation === undefined &&
      node.nodes &&
      node.nodes.length === 1 &&
      node.nodes[0].sassType === 'rule'
    ) {
      this.block(
        node.nodes[0],
        '@at-root' +
          (node.raws.afterName ?? ' ') +
          node.nodes[0].selectorInterpolation,
      );
      return;
    }

    const start =
      `@${node.nameInterpolation}` +
      (node.raws.afterName ?? (node.paramsInterpolation ? ' ' : '')) +
      node.params;
    if (node.nodes) {
      this.block(node, start);
    } else {
      this.builder(
        start + (node.raws.between ?? '') + (semicolon ? ';' : ''),
        node,
      );
    }
  }

  private ['return-rule'](node: ReturnRule, semicolon: boolean): void {
    this.sassAtRule(node, semicolon);
  }

  private rule(node: Rule): void {
    this.block(node, node.selectorInterpolation.toString());
  }

  private ['sass-comment'](node: SassComment): void {
    const before = node.raws.before ?? '';
    const left = node.raws.left ?? ' ';
    let text = node.text
      .split('\n')
      .map(
        (line, i) =>
          before +
          (node.raws.beforeLines?.[i] ?? '') +
          '//' +
          (/[^ \t]/.test(line) ? left : '') +
          line,
      )
      .join('\n');

    // Ensure that a Sass-style comment always has a newline after it unless
    // it's the last node in the document.
    const next = node.next();
    if (next && !this.raw(next, 'before').startsWith('\n')) {
      text += '\n';
    } else if (
      !next &&
      node.parent &&
      !this.raw(node.parent, 'after').startsWith('\n')
    ) {
      text += '\n';
    }

    this.builder(text, node);
  }

  private ['use-rule'](node: UseRule, semicolon: boolean): void {
    this.sassAtRule(node, semicolon);
  }

  private ['warn-rule'](node: WarnRule, semicolon: boolean): void {
    this.sassAtRule(node, semicolon);
  }

  private ['variable-declaration'](
    node: VariableDeclaration,
    semicolon: boolean,
  ): void {
    this.builder(
      node.prop +
        this.raw(node, 'between', 'colon') +
        node.expression +
        (node.raws.flags?.value?.guarded === node.guarded &&
        node.raws.flags?.value?.global === node.global
          ? node.raws.flags.raw
          : (node.guarded ? ' !default' : '') +
            (node.global ? ' !global' : '')) +
        (node.raws.afterValue ?? '') +
        (semicolon ? ';' : ''),
      node,
    );
  }

  private ['while-rule'](node: WhileRule): void {
    this.sassAtRule(node);
  }

  /** Helper method for non-generic Sass at-rules. */
  private sassAtRule(node: postcss.AtRule, semicolon?: boolean): void {
    const start =
      '@' +
      node.name +
      (node.raws.afterName ?? (node.params === '' ? '' : ' ')) +
      node.params;
    if (node.nodes) {
      this.block(node, start);
    } else {
      this.builder(
        start + (node.raws.between ?? '') + (semicolon ? ';' : ''),
        node,
      );
    }
  }
}
