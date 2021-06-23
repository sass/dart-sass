// To reproduce:
//
// * pub get
// * pub run grinder pkg-npm-dev
// * node repro.js

const sass = require('./build/npm/sass.dart');

sass.render({
  data: `@debug null;\n`,
}, (err, result) => {
  console.log({err, result});
});
