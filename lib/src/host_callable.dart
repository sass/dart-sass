// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:cli';
import 'dart:io';

import 'package:sass/sass.dart' as sass;

import 'dispatcher.dart';
import 'embedded_sass.pb.dart';
import 'function_registry.dart';
import 'utils.dart';
import 'value.dart';

/// Returns a Sass callable that invokes a function defined on the host with the
/// given [signature].
///
/// If [id] is passed, the function will be called by ID (which is necessary for
/// anonymous functions defined on the host). Otherwise, it will be called using
/// the name defined in the [signature].
///
/// Throws a [ProtocolError] if [signature] is invalid.
sass.Callable hostCallable(Dispatcher dispatcher, FunctionRegistry functions,
    int compilationId, String signature,
    {int? id}) {
  var openParen = signature.indexOf('(');
  if (openParen == -1) {
    throw paramsError(
        'CompileRequest.global_functions: "$signature" is missing "("');
  }

  if (!signature.endsWith(")")) {
    throw paramsError(
        'CompileRequest.global_functions: "$signature" doesn\'t end with '
        '")"');
  }

  var name = signature.substring(0, openParen);
  try {
    return sass.Callable.function(
        name, signature.substring(openParen + 1, signature.length - 1),
        (arguments) {
      var request = OutboundMessage_FunctionCallRequest()
        ..compilationId = compilationId
        ..arguments.addAll([
          for (var argument in arguments) protofyValue(functions, argument)
        ]);

      if (id != null) {
        request.functionId = id;
      } else {
        request.name = name;
      }

      var response = waitFor(dispatcher.sendFunctionCallRequest(request));
      try {
        switch (response.whichResult()) {
          case InboundMessage_FunctionCallResponse_Result.success:
            return deprotofyValue(
                dispatcher, functions, compilationId, response.success);

          case InboundMessage_FunctionCallResponse_Result.error:
            throw response.error;

          case InboundMessage_FunctionCallResponse_Result.notSet:
            throw mandatoryError('FunctionCallResponse.result');
        }
      } on ProtocolError catch (error) {
        error.id = errorId;
        stderr.writeln("Host caused ${error.type.name.toLowerCase()} error: "
            "${error.message}");
        dispatcher.sendError(error);
        throw error.message;
      }
    });
  } on sass.SassException catch (error) {
    throw paramsError('CompileRequest.global_functions: $error');
  }
}
