// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {GenericAtRule, Root, Rule} from '../..';

describe('a container node', () => {
  describe('with nodes', () => {
    let root: Root;
    beforeEach(() => {
      root = new Root();
    });

    describe('can add', () => {
      it('a single Sass node', () => {
        const rule = new Rule({selector: '.foo'});
        root.append(rule);
        expect(root.nodes).toEqual([rule]);
        expect(rule.parent).toBe(root);
      });

      it('a list of Sass nodes', () => {
        const rule1 = new Rule({selector: '.foo'});
        const rule2 = new Rule({selector: '.bar'});
        root.append([rule1, rule2]);
        expect(root.nodes).toEqual([rule1, rule2]);
        expect(rule1.parent).toBe(root);
        expect(rule2.parent).toBe(root);
      });

      it('a Sass root node', () => {
        const rule1 = new Rule({selector: '.foo'});
        const rule2 = new Rule({selector: '.bar'});
        const otherRoot = new Root({nodes: [rule1, rule2]});
        root.append(otherRoot);
        expect(root.nodes[0]).toBeInstanceOf(Rule);
        expect(root.nodes[0]).toHaveNode('parsedSelector', '.foo');
        expect(root.nodes[1]).toBeInstanceOf(Rule);
        expect(root.nodes[1]).toHaveNode('parsedSelector', '.bar');
        expect(root.nodes[0].parent).toBe(root);
        expect(root.nodes[1].parent).toBe(root);
        expect(rule1.parent).toBeUndefined();
        expect(rule2.parent).toBeUndefined();
      });

      it('a PostCSS rule node', () => {
        const node = postcss.parse('.foo {}').nodes[0];
        root.append(node);
        expect(root.nodes[0]).toBeInstanceOf(Rule);
        expect(root.nodes[0]).toHaveNode('parsedSelector', '.foo');
        expect(root.nodes[0].parent).toBe(root);
        expect(root.nodes[0].source).toBe(node.source);
        expect(node.parent).toBeUndefined();
      });

      it('a PostCSS at-rule node', () => {
        const node = postcss.parse('@foo bar').nodes[0];
        root.append(node);
        expect(root.nodes[0]).toBeInstanceOf(GenericAtRule);
        expect(root.nodes[0]).toHaveInterpolation('nameInterpolation', 'foo');
        expect(root.nodes[0]).toHaveInterpolation('paramsInterpolation', 'bar');
        expect(root.nodes[0].parent).toBe(root);
        expect(root.nodes[0].source).toBe(node.source);
        expect(node.parent).toBeUndefined();
      });

      it('a list of PostCSS nodes', () => {
        const rule1 = new postcss.Rule({selector: '.foo'});
        const rule2 = new postcss.Rule({selector: '.bar'});
        root.append([rule1, rule2]);
        expect(root.nodes[0]).toBeInstanceOf(Rule);
        expect(root.nodes[0]).toHaveNode('parsedSelector', '.foo');
        expect(root.nodes[1]).toBeInstanceOf(Rule);
        expect(root.nodes[1]).toHaveNode('parsedSelector', '.bar');
        expect(root.nodes[0].parent).toBe(root);
        expect(root.nodes[1].parent).toBe(root);
        expect(rule1.parent).toBeUndefined();
        expect(rule2.parent).toBeUndefined();
      });

      it('a PostCSS root node', () => {
        const rule1 = new postcss.Rule({selector: '.foo'});
        const rule2 = new postcss.Rule({selector: '.bar'});
        const otherRoot = new postcss.Root({nodes: [rule1, rule2]});
        root.append(otherRoot);
        expect(root.nodes[0]).toBeInstanceOf(Rule);
        expect(root.nodes[0]).toHaveNode('parsedSelector', '.foo');
        expect(root.nodes[1]).toBeInstanceOf(Rule);
        expect(root.nodes[1]).toHaveNode('parsedSelector', '.bar');
        expect(root.nodes[0].parent).toBe(root);
        expect(root.nodes[1].parent).toBe(root);
        expect(rule1.parent).toBeUndefined();
        expect(rule2.parent).toBeUndefined();
      });

      it("a single Sass node's properties", () => {
        root.append({parsedSelector: {class: 'foo'}});
        expect(root.nodes[0]).toBeInstanceOf(Rule);
        expect(root.nodes[0]).toHaveNode('parsedSelector', '.foo');
        expect(root.nodes[0].parent).toBe(root);
      });

      it("a single PostCSS node's properties", () => {
        root.append({selector: '.foo'});
        expect(root.nodes[0]).toBeInstanceOf(Rule);
        expect(root.nodes[0]).toHaveNode('parsedSelector', '.foo');
        expect(root.nodes[0].parent).toBe(root);
      });

      it('a list of properties', () => {
        root.append(
          {parsedSelector: {class: 'foo'}},
          {parsedSelector: {class: 'bar'}},
        );
        expect(root.nodes[0]).toBeInstanceOf(Rule);
        expect(root.nodes[0]).toHaveNode('parsedSelector', '.foo');
        expect(root.nodes[1]).toBeInstanceOf(Rule);
        expect(root.nodes[1]).toHaveNode('parsedSelector', '.bar');
        expect(root.nodes[0].parent).toBe(root);
        expect(root.nodes[1].parent).toBe(root);
      });

      it('a plain CSS string', () => {
        root.append('.foo {}');
        expect(root.nodes[0]).toBeInstanceOf(Rule);
        expect(root.nodes[0]).toHaveNode('parsedSelector', '.foo');
        expect(root.nodes[0].parent).toBe(root);
      });

      it('a list of plain CSS strings', () => {
        root.append(['.foo {}', '.bar {}']);
        expect(root.nodes[0]).toBeInstanceOf(Rule);
        expect(root.nodes[0]).toHaveNode('parsedSelector', '.foo');
        expect(root.nodes[1]).toBeInstanceOf(Rule);
        expect(root.nodes[1]).toHaveNode('parsedSelector', '.bar');
        expect(root.nodes[0].parent).toBe(root);
        expect(root.nodes[1].parent).toBe(root);
      });

      it('undefined', () => {
        root.append(undefined);
        expect(root.nodes).toHaveLength(0);
      });
    });
  });

  describe('without nodes', () => {
    let rule: GenericAtRule;
    beforeEach(() => {
      rule = new GenericAtRule({name: 'foo'});
    });

    describe('can add', () => {
      it('a node', () => {
        rule.append('@bar');
        expect(rule.nodes).not.toBeUndefined();
        expect(rule.nodes![0]).toBeInstanceOf(GenericAtRule);
        expect(rule.nodes![0]).toHaveInterpolation('nameInterpolation', 'bar');
      });

      it('undefined', () => {
        rule.append(undefined);
        expect(rule.nodes).not.toBeUndefined();
        expect(rule.nodes).toHaveLength(0);
      });
    });
  });
});
