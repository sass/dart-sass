// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Interpolation, StringExpression} from '../..';
import * as utils from '../../../test/utils';

describe('a string expression', () => {
  let node: StringExpression;
  describe('quoted', () => {
    function describeNode(
      description: string,
      create: () => StringExpression
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType string', () => expect(node.sassType).toBe('string'));

        it('has quotes', () => expect(node.quotes).toBe(true));

        it('has text', () => expect(node).toHaveInterpolation('text', 'foo'));
      });
    }

    describeNode('parsed', () => utils.parseExpression('"foo"'));

    describe('constructed manually', () => {
      describeNode(
        'with explicit text',
        () =>
          new StringExpression({
            quotes: true,
            text: new Interpolation({nodes: ['foo']}),
          })
      );

      describeNode(
        'with string text',
        () =>
          new StringExpression({
            quotes: true,
            text: 'foo',
          })
      );
    });

    describe('constructed from ExpressionProps', () => {
      describeNode('with explicit text', () =>
        utils.fromExpressionProps({
          quotes: true,
          text: new Interpolation({nodes: ['foo']}),
        })
      );

      describeNode('with string text', () =>
        utils.fromExpressionProps({
          quotes: true,
          text: 'foo',
        })
      );
    });
  });

  describe('unquoted', () => {
    function describeNode(
      description: string,
      create: () => StringExpression
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType string', () => expect(node.sassType).toBe('string'));

        it('has no quotes', () => expect(node.quotes).toBe(false));

        it('has text', () => expect(node).toHaveInterpolation('text', 'foo'));
      });
    }

    describeNode('parsed', () => utils.parseExpression('foo'));

    describe('constructed manually', () => {
      describeNode(
        'with explicit text',
        () =>
          new StringExpression({
            text: new Interpolation({nodes: ['foo']}),
          })
      );

      describeNode(
        'with explicit quotes',
        () =>
          new StringExpression({
            quotes: false,
            text: 'foo',
          })
      );

      describeNode(
        'with string text',
        () =>
          new StringExpression({
            text: 'foo',
          })
      );
    });

    describe('constructed from ExpressionProps', () => {
      describeNode('with explicit text', () =>
        utils.fromExpressionProps({
          text: new Interpolation({nodes: ['foo']}),
        })
      );

      describeNode('with explicit quotes', () =>
        utils.fromExpressionProps({
          quotes: false,
          text: 'foo',
        })
      );

      describeNode('with string text', () =>
        utils.fromExpressionProps({
          text: 'foo',
        })
      );
    });
  });

  describe('assigned new', () => {
    beforeEach(() => void (node = utils.parseExpression('"foo"')));

    it('quotes', () => {
      node.quotes = false;
      expect(node.quotes).toBe(false);
    });

    describe('text', () => {
      it("removes the old text's parent", () => {
        const oldText = node.text;
        node.text = 'zip';
        expect(oldText.parent).toBeUndefined();
      });

      it('assigns text explicitly', () => {
        const text = new Interpolation({nodes: ['zip']});
        node.text = text;
        expect(node.text).toBe(text);
        expect(node).toHaveInterpolation('text', 'zip');
      });

      it('assigns text as string', () => {
        node.text = 'zip';
        expect(node).toHaveInterpolation('text', 'zip');
      });
    });
  });

  describe('stringifies', () => {
    describe('quoted', () => {
      describe('with no internal quotes', () => {
        beforeEach(() => void (node = utils.parseExpression('"foo"')));

        it('without raws', () => expect(node.toString()).toBe('"foo"'));

        it('with explicit double quotes', () => {
          node.raws.quotes = '"';
          expect(node.toString()).toBe('"foo"');
        });

        it('with explicit single quotes', () => {
          node.raws.quotes = "'";
          expect(node.toString()).toBe("'foo'");
        });
      });

      describe('with internal double quote', () => {
        beforeEach(() => void (node = utils.parseExpression("'f\"o'")));

        it('without raws', () => expect(node.toString()).toBe('"f\\"o"'));

        it('with explicit double quotes', () => {
          node.raws.quotes = '"';
          expect(node.toString()).toBe('"f\\"o"');
        });

        it('with explicit single quotes', () => {
          node.raws.quotes = "'";
          expect(node.toString()).toBe("'f\"o'");
        });
      });

      describe('with internal single quote', () => {
        beforeEach(() => void (node = utils.parseExpression('"f\'o"')));

        it('without raws', () => expect(node.toString()).toBe('"f\'o"'));

        it('with explicit double quotes', () => {
          node.raws.quotes = '"';
          expect(node.toString()).toBe('"f\'o"');
        });

        it('with explicit single quotes', () => {
          node.raws.quotes = "'";
          expect(node.toString()).toBe("'f\\'o'");
        });
      });

      it('with internal unprintable', () =>
        expect(
          new StringExpression({quotes: true, text: '\x00'}).toString()
        ).toBe('"\\0 "'));

      it('with internal newline', () =>
        expect(
          new StringExpression({quotes: true, text: '\x0A'}).toString()
        ).toBe('"\\a "'));

      it('with internal backslash', () =>
        expect(
          new StringExpression({quotes: true, text: '\\'}).toString()
        ).toBe('"\\\\"'));

      it('respects interpolation raws', () =>
        expect(
          new StringExpression({
            quotes: true,
            text: new Interpolation({
              nodes: ['foo'],
              raws: {text: [{raw: 'f\\6f o', value: 'foo'}]},
            }),
          }).toString()
        ).toBe('"f\\6f o"'));
    });

    describe('unquoted', () => {
      it('prints the text as-is', () =>
        expect(utils.parseExpression('foo').toString()).toBe('foo'));

      it('with internal quotes', () =>
        expect(new StringExpression({text: '"'}).toString()).toBe('"'));

      it('with internal newline', () =>
        expect(new StringExpression({text: '\x0A'}).toString()).toBe('\x0A'));

      it('with internal backslash', () =>
        expect(new StringExpression({text: '\\'}).toString()).toBe('\\'));

      it('respects interpolation raws', () =>
        expect(
          new StringExpression({
            text: new Interpolation({
              nodes: ['foo'],
              raws: {text: [{raw: 'f\\6f o', value: 'foo'}]},
            }),
          }).toString()
        ).toBe('f\\6f o'));
    });
  });

  describe('clone', () => {
    let original: StringExpression;
    beforeEach(() => {
      original = utils.parseExpression('"foo"');
      // TODO: remove this once raws are properly parsed
      original.raws.quotes = "'";
    });

    describe('with no overrides', () => {
      let clone: StringExpression;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('quotes', () => expect(clone.quotes).toBe(true));

        it('text', () => expect(clone).toHaveInterpolation('text', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({quotes: "'"}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['text', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('quotes', () => {
        it('defined', () =>
          expect(original.clone({quotes: false}).quotes).toBe(false));

        it('undefined', () =>
          expect(original.clone({quotes: undefined}).quotes).toBe(true));
      });

      describe('text', () => {
        it('defined', () =>
          expect(original.clone({text: 'zip'})).toHaveInterpolation(
            'text',
            'zip'
          ));

        it('undefined', () =>
          expect(original.clone({text: undefined})).toHaveInterpolation(
            'text',
            'foo'
          ));
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {quotes: '"'}}).raws).toEqual({
            quotes: '"',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            quotes: "'",
          }));
      });
    });
  });

  it('toJSON', () => expect(utils.parseExpression('"foo"')).toMatchSnapshot());
});
