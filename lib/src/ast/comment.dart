// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'node.dart';

class CommentNode implements AstNode {
  final String text;

  final bool isSilent;

  final SourceSpan span;

  // TODO: Reformat text.
  CommentNode(this.text, {bool silent, this.span})
      : isSilent = silent;

  String toString() => text;
}