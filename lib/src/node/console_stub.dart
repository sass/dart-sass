// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

abstract class Console {
  external void log(String data);
  external void info(String data);
  external void warn(String data);
  external void error(String data);
}

Console get console => throw '';
