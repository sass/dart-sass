import {defineConfig, globalIgnores} from 'eslint/config';
import tseslint from 'typescript-eslint';
import gts from 'gts';

export default defineConfig([
  globalIgnores(['**/dist/', '**/*.js']),
  {
    extends: [tseslint.configs.recommended, gts],
    rules: {
      '@typescript-eslint/explicit-function-return-type': [
        'error',
        {allowExpressions: true},
      ],
      '@typescript-eslint/no-empty-interface': ['error'],
      'func-style': ['error', 'declaration'],
      'prefer-const': ['error', {destructuring: 'all'}],
      'sort-imports': ['error', {ignoreDeclarationSort: true}],
      // TODO: Should this be turned on?
      'prettier/prettier': ['off'],
    },
  },
]);
