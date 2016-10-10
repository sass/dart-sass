// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

export 'callable/built_in.dart';
export 'callable/user_defined.dart';

/// An interface for objects, such as functions and mixins, that can be invoked
/// from Sass by passing in arguments.
abstract class Callable {
  /// The callable's name.
  String get name;

  // TODO(nweiz): I'd like to include the argument declaration on this interface
  // as well, but supporting overloads for built-in callables makes that more
  // difficult. Ideally, we'd define overloads as purely an implementation
  // detail of functions, using a helper method. But that would need to
  // duplicate a lot of the logic in PerformVisitor, and I can't find an elegant
  // way to do that.
}
