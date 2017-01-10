var sass = require('../../build/sass.dart.js');

sass.render({
  file: 'import-file.scss'
}, function (err, result) {
  console.log('error:', err);
  console.log('result:\n', result.buffer.toString());
});
