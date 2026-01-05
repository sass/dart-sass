// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  IfConditionExpression,
  IfConditionSass,
  IfEntry,
  IfExpression,
  StringExpression,
  VariableExpression,
} from '../..';
import * as utils from '../../../test/utils';

describe('an if() entry', () => {
  let node: IfEntry;
  beforeEach(
    () =>
      void (node = new IfEntry({
        condition: {variableName: 'foo'},
        value: {text: 'bar'},
      })),
  );

  describe('with a condition', () => {
    function describeNode(description: string, create: () => IfEntry): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('if-entry'));

        it('has a condition', () =>
          expect(node).toHaveNode('condition', 'sass($foo)'));

        it('has a value', () =>
          expect(node).toHaveStringExpression('value', 'bar'));
      });
    }

    describeNode(
      'parsed',
      () =>
        (utils.parseExpression('if(sass($foo): bar)') as IfExpression).nodes[0],
    );

    describe('constructed manually', () => {
      describe('with an array', () => {
        describeNode(
          'with a Condition and an Expression',
          () =>
            new IfEntry([
              new IfConditionSass({variableName: 'foo'}),
              new StringExpression({text: 'bar'}),
            ]),
        );

        describeNode(
          'with two Expressions',
          () =>
            new IfEntry([
              new VariableExpression({variableName: 'foo'}),
              new StringExpression({text: 'bar'}),
            ]),
        );

        describeNode(
          'with an IfConditionExpressionProps and an ExpressionProps',
          () =>
            new IfEntry([{expression: {variableName: 'foo'}}, {text: 'bar'}]),
        );

        describeNode(
          'with two ExpressionProps',
          () => new IfEntry([{variableName: 'foo'}, {text: 'bar'}]),
        );
      });

      describe('with an object', () => {
        describeNode(
          'with a Condition and an Expression',
          () =>
            new IfEntry({
              condition: new IfConditionSass({variableName: 'foo'}),
              value: new StringExpression({text: 'bar'}),
            }),
        );

        describeNode(
          'with two Expressions',
          () =>
            new IfEntry({
              condition: new VariableExpression({variableName: 'foo'}),
              value: new StringExpression({text: 'bar'}),
            }),
        );

        describeNode(
          'with an IfConditionExpressionProps and an ExpressionProps',
          () =>
            new IfEntry({
              condition: {expression: {variableName: 'foo'}},
              value: {text: 'bar'},
            }),
        );

        describeNode(
          'with ExpressionProps',
          () =>
            new IfEntry({
              condition: {variableName: 'foo'},
              value: {text: 'bar'},
            }),
        );
      });
    });
  });

  describe('with else', () => {
    function describeNode(description: string, create: () => IfEntry): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('if-entry'));

        it('has else', () => expect(node.condition).toBe('else'));

        it('has a value', () =>
          expect(node).toHaveStringExpression('value', 'foo'));
      });
    }

    describeNode(
      'parsed',
      () => (utils.parseExpression('if(else: foo)') as IfExpression).nodes[0],
    );

    describe('constructed manually', () => {
      describe('with an array', () => {
        describeNode(
          'with an Expression',
          () => new IfEntry(['else', new StringExpression({text: 'foo'})]),
        );

        describeNode(
          'with an ExpressionProps',
          () => new IfEntry(['else', {text: 'foo'}]),
        );
      });

      describe('with an object', () => {
        describeNode(
          'with an Expression',
          () =>
            new IfEntry({
              condition: 'else',
              value: new StringExpression({text: 'foo'}),
            }),
        );

        describeNode(
          'with ExpressionProps',
          () => new IfEntry({condition: 'else', value: {text: 'foo'}}),
        );
      });
    });
  });

  describe('assigned a new condition', () => {
    it('IfConditionExpression', () => {
      const old = node.condition;
      const condition = new IfConditionSass({variableName: 'baz'});
      node.condition = condition;
      expect((old as IfConditionExpression).parent).toBeUndefined();
      expect(node.condition).toBe(condition);
      expect(node).toHaveNode('condition', 'sass($baz)');
    });

    it('IfConditionExpressionProps', () => {
      const old = node.condition;
      node.condition = {expression: {variableName: 'baz'}};
      expect((old as IfConditionExpression).parent).toBeUndefined();
      expect(node).toHaveNode('condition', 'sass($baz)');
    });

    it('Expression', () => {
      const old = node.condition;
      const condition = new VariableExpression({variableName: 'baz'});
      node.condition = condition;
      expect((old as IfConditionExpression).parent).toBeUndefined();
      expect((node.condition as IfConditionSass).expression).toBe(condition);
      expect(node).toHaveNode('condition', 'sass($baz)');
    });

    it('ExpressionProps', () => {
      const old = node.condition;
      node.condition = {variableName: 'baz'};
      expect((old as IfConditionExpression).parent).toBeUndefined();
      expect(node).toHaveNode('condition', 'sass($baz)');
    });
  });

  describe('assigned a new value', () => {
    it('Expression', () => {
      const old = node.value;
      const value = new StringExpression({text: 'baz'});
      node.value = value;
      expect(old.parent).toBeUndefined();
      expect(node.value).toBe(value);
      expect(node).toHaveStringExpression('value', 'baz');
    });

    it('ExpressionProps', () => {
      const old = node.value;
      node.value = {text: 'baz'};
      expect(old.parent).toBeUndefined();
      expect(node).toHaveStringExpression('value', 'baz');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with a condition', () => {
        beforeEach(() => {
          node = new IfEntry({
            condition: {variableName: 'foo'},
            value: {text: 'bar'},
          });
        });

        it('with default raws', () =>
          expect(node.toString()).toBe('sass($foo): bar'));

        it('ignores else', () => {
          node.raws.else = 'ELSE';
          expect(node.toString()).toBe('sass($foo): bar');
        });

        // raws.before is only used as part of a IfExpression
        it('ignores before', () => {
          node.raws.before = '/**/';
          expect(node.toString()).toBe('sass($foo): bar');
        });

        it('with between', () => {
          node.raws.between = ' :';
          expect(node.toString()).toBe('sass($foo) :bar');
        });

        it('ignores after', () => {
          node.raws.after = '/**/';
          expect(node.toString()).toBe('sass($foo): bar');
        });
      });

      describe('with else', () => {
        beforeEach(() => {
          node = new IfEntry({
            condition: 'else',
            value: {text: 'bar'},
          });
        });

        it('with default raws', () =>
          expect(node.toString()).toBe('else: bar'));

        it('with else', () => {
          node.raws.else = 'ELSE';
          expect(node.toString()).toBe('ELSE: bar');
        });

        // raws.before is only used as part of a IfExpression
        it('ignores before', () => {
          node.raws.before = '/**/';
          expect(node.toString()).toBe('else: bar');
        });

        it('with between', () => {
          node.raws.between = ' :';
          expect(node.toString()).toBe('else :bar');
        });

        it('ignores after', () => {
          node.raws.after = '/**/';
          expect(node.toString()).toBe('else: bar');
        });
      });
    });
  });

  describe('clone()', () => {
    let original: IfEntry;
    beforeEach(() => {
      original = (utils.parseExpression('if(sass($foo): bar)') as IfExpression)
        .nodes[0];
      original.raws.between = ' : ';
    });

    describe('with no overrides', () => {
      let clone: IfEntry;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('key', () => expect(clone).toHaveNode('condition', 'sass($foo)'));

        it('value', () => expect(clone).toHaveStringExpression('value', 'bar'));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['condition', 'value', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {before: '  '}}).raws).toEqual({
            before: '  ',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            between: ' : ',
          }));
      });

      describe('condition', () => {
        it('defined', () =>
          expect(original.clone({condition: {variableName: 'baz'}})).toHaveNode(
            'condition',
            'sass($baz)',
          ));

        it('undefined', () =>
          expect(original.clone({condition: undefined})).toHaveNode(
            'condition',
            'sass($foo)',
          ));
      });

      describe('value', () => {
        it('defined', () =>
          expect(original.clone({value: {text: 'baz'}})).toHaveStringExpression(
            'value',
            'baz',
          ));

        it('undefined', () =>
          expect(original.clone({value: undefined})).toHaveStringExpression(
            'value',
            'bar',
          ));
      });
    });
  });

  describe('toJSON', () => {
    it('with condition', () =>
      expect(
        (utils.parseExpression('if(sass($foo): bar)') as IfExpression).nodes[0],
      ).toMatchSnapshot());

    it('with else', () =>
      expect(
        (utils.parseExpression('if(else: foo)') as IfExpression).nodes[0],
      ).toMatchSnapshot());
  });
});
