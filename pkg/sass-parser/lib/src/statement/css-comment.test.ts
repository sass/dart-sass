// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {CssComment, Interpolation, Root, css, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a CSS-style comment', () => {
  let node: CssComment;
  function describeNode(description: string, create: () => CssComment): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has type comment', () => expect(node.type).toBe('comment'));

      it('has sassType comment', () => expect(node.sassType).toBe('comment'));

      it('has matching textInterpolation', () =>
        expect(node).toHaveInterpolation('textInterpolation', 'foo'));

      it('has matching text', () => expect(node.text).toBe('foo'));
    });
  }

  describeNode(
    'parsed as SCSS',
    () => scss.parse('/* foo */').nodes[0] as CssComment
  );

  describeNode(
    'parsed as CSS',
    () => css.parse('/* foo */').nodes[0] as CssComment
  );

  describeNode(
    'parsed as Sass',
    () => sass.parse('/* foo').nodes[0] as CssComment
  );

  describe('constructed manually', () => {
    describeNode(
      'with an interpolation',
      () =>
        new CssComment({
          textInterpolation: new Interpolation({nodes: ['foo']}),
        })
    );

    describeNode('with a text string', () => new CssComment({text: 'foo'}));
  });

  describe('constructed from ChildProps', () => {
    describeNode('with an interpolation', () =>
      utils.fromChildProps({
        textInterpolation: new Interpolation({nodes: ['foo']}),
      })
    );

    describeNode('with a text string', () =>
      utils.fromChildProps({text: 'foo'})
    );
  });

  describe('parses raws', () => {
    describe('in SCSS', () => {
      it('with whitespace before and after text', () =>
        expect((scss.parse('/* foo */').nodes[0] as CssComment).raws).toEqual({
          left: ' ',
          right: ' ',
          closed: true,
        }));

      it('with whitespace before and after interpolation', () =>
        expect(
          (scss.parse('/* #{foo} */').nodes[0] as CssComment).raws
        ).toEqual({left: ' ', right: ' ', closed: true}));

      it('without whitespace before and after text', () =>
        expect((scss.parse('/*foo*/').nodes[0] as CssComment).raws).toEqual({
          left: '',
          right: '',
          closed: true,
        }));

      it('without whitespace before and after interpolation', () =>
        expect((scss.parse('/*#{foo}*/').nodes[0] as CssComment).raws).toEqual({
          left: '',
          right: '',
          closed: true,
        }));

      it('with whitespace and no text', () =>
        expect((scss.parse('/* */').nodes[0] as CssComment).raws).toEqual({
          left: ' ',
          right: '',
          closed: true,
        }));

      it('with no whitespace and no text', () =>
        expect((scss.parse('/**/').nodes[0] as CssComment).raws).toEqual({
          left: '',
          right: '',
          closed: true,
        }));
    });

    describe('in Sass', () => {
      // TODO: Test explicit whitespace after text and interpolation once we
      // properly parse raws from somewhere other than the original text.

      it('with whitespace before text', () =>
        expect((sass.parse('/* foo').nodes[0] as CssComment).raws).toEqual({
          left: ' ',
          right: '',
          closed: false,
        }));

      it('with whitespace before interpolation', () =>
        expect((sass.parse('/* #{foo}').nodes[0] as CssComment).raws).toEqual({
          left: ' ',
          right: '',
          closed: false,
        }));

      it('without whitespace before and after text', () =>
        expect((sass.parse('/*foo').nodes[0] as CssComment).raws).toEqual({
          left: '',
          right: '',
          closed: false,
        }));

      it('without whitespace before and after interpolation', () =>
        expect((sass.parse('/*#{foo}').nodes[0] as CssComment).raws).toEqual({
          left: '',
          right: '',
          closed: false,
        }));

      it('with no whitespace and no text', () =>
        expect((sass.parse('/*').nodes[0] as CssComment).raws).toEqual({
          left: '',
          right: '',
          closed: false,
        }));

      it('with a trailing */', () =>
        expect((sass.parse('/* foo */').nodes[0] as CssComment).raws).toEqual({
          left: ' ',
          right: ' ',
          closed: true,
        }));
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(new CssComment({text: 'foo'}).toString()).toBe('/* foo */'));

      it('with left', () =>
        expect(
          new CssComment({
            text: 'foo',
            raws: {left: '\n'},
          }).toString()
        ).toBe('/*\nfoo */'));

      it('with right', () =>
        expect(
          new CssComment({
            text: 'foo',
            raws: {right: '\n'},
          }).toString()
        ).toBe('/* foo\n*/'));

      it('with before', () =>
        expect(
          new Root({
            nodes: [new CssComment({text: 'foo', raws: {before: '/**/'}})],
          }).toString()
        ).toBe('/**//* foo */'));
    });
  });

  describe('assigned new text', () => {
    beforeEach(() => {
      node = scss.parse('/* foo */').nodes[0] as CssComment;
    });

    it("removes the old text's parent", () => {
      const oldText = node.textInterpolation!;
      node.textInterpolation = 'bar';
      expect(oldText.parent).toBeUndefined();
    });

    it("assigns the new interpolation's parent", () => {
      const interpolation = new Interpolation({nodes: ['bar']});
      node.textInterpolation = interpolation;
      expect(interpolation.parent).toBe(node);
    });

    it('assigns the interpolation explicitly', () => {
      const interpolation = new Interpolation({nodes: ['bar']});
      node.textInterpolation = interpolation;
      expect(node.textInterpolation).toBe(interpolation);
    });

    it('assigns the interpolation as a string', () => {
      node.textInterpolation = 'bar';
      expect(node).toHaveInterpolation('textInterpolation', 'bar');
    });

    it('assigns the interpolation as text', () => {
      node.text = 'bar';
      expect(node).toHaveInterpolation('textInterpolation', 'bar');
    });
  });

  describe('clone', () => {
    let original: CssComment;
    beforeEach(
      () => void (original = scss.parse('/* foo */').nodes[0] as CssComment)
    );

    describe('with no overrides', () => {
      let clone: CssComment;
      beforeEach(() => {
        clone = original.clone();
      });

      describe('has the same properties:', () => {
        it('textInterpolation', () =>
          expect(clone).toHaveInterpolation('textInterpolation', 'foo'));

        it('text', () => expect(clone.text).toBe('foo'));

        it('raws', () =>
          expect(clone.raws).toEqual({left: ' ', right: ' ', closed: true}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['textInterpolation', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('text', () => {
        describe('defined', () => {
          let clone: CssComment;
          beforeEach(() => {
            clone = original.clone({text: 'bar'});
          });

          it('changes text', () => expect(clone.text).toBe('bar'));

          it('changes textInterpolation', () =>
            expect(clone).toHaveInterpolation('textInterpolation', 'bar'));
        });

        describe('undefined', () => {
          let clone: CssComment;
          beforeEach(() => {
            clone = original.clone({text: undefined});
          });

          it('preserves text', () => expect(clone.text).toBe('foo'));

          it('preserves textInterpolation', () =>
            expect(clone).toHaveInterpolation('textInterpolation', 'foo'));
        });
      });

      describe('textInterpolation', () => {
        describe('defined', () => {
          let clone: CssComment;
          beforeEach(() => {
            clone = original.clone({
              textInterpolation: new Interpolation({nodes: ['baz']}),
            });
          });

          it('changes text', () => expect(clone.text).toBe('baz'));

          it('changes textInterpolation', () =>
            expect(clone).toHaveInterpolation('textInterpolation', 'baz'));
        });

        describe('undefined', () => {
          let clone: CssComment;
          beforeEach(() => {
            clone = original.clone({textInterpolation: undefined});
          });

          it('preserves text', () => expect(clone.text).toBe('foo'));

          it('preserves textInterpolation', () =>
            expect(clone).toHaveInterpolation('textInterpolation', 'foo'));
        });
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {right: '  '}}).raws).toEqual({
            right: '  ',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            left: ' ',
            right: ' ',
            closed: true,
          }));
      });
    });
  });

  it('toJSON', () =>
    expect(scss.parse('/* foo */').nodes[0]).toMatchSnapshot());
});
