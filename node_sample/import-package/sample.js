var sass = require('../../build/sass.dart.js');

sass.render({
  file: 'import-package.scss'
}, function (err, result) {
  console.log('error:', err);
  console.log('result:', result.buffer.toString());
});
