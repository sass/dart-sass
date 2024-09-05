const fs = require('node:fs');
const jsonc = require('jsonc-parser');

module.exports = jsonc.parse(
  fs.readFileSync(require.resolve('./.eslintrc'), 'utf8')
);
