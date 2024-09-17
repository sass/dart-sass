// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'embedded_sass.pb.dart' hide SourceSpan;
import 'protofier.dart';
import '../ast/sass.dart';
import '../exception.dart';
import '../import_cache.dart';
import '../importer/no_op.dart';
import '../logger.dart';
import '../parse/parser.dart';
import '../visitor/evaluate.dart';

OutboundMessage_EvaluateResponse evaluate(
    InboundMessage_EvaluateRequest request) {
  var protofier = StatelessProtofier();
  var logger = Logger.quiet;
  var evaluator = Evaluator(
      importer: NoOpImporter(),
      importCache: ImportCache(logger: logger),
      logger: logger);

  try {
    request.variables.forEach((name, value) {
      var span = SourceFile.fromString(name).span(0, name.length);
      var declaration = VariableDeclaration(Parser.parseIdentifier(name),
          ValueExpression(protofier.deprotofy(value), span), span);
      evaluator.setVariable(declaration);
    });

    for (var line in request.statements) {
      if (line.startsWith("@")) {
        evaluator.use(UseRule.parse(line, logger: logger));
        continue;
      }

      if (Parser.isVariableDeclarationLike(line)) {
        var declaration = VariableDeclaration.parse(line, logger: logger);
        evaluator.setVariable(declaration);
      }

      throw SassScriptException(
          'Only UseRule and VariableDeclaration are allowed in statements.');
    }

    var value = evaluator
        .evaluate(Expression.parse(request.expression, logger: logger));
    return OutboundMessage_EvaluateResponse()
      ..id = request.id
      ..value = protofier.protofy(value);
  } on SassException catch (error) {
    return OutboundMessage_EvaluateResponse()
      ..id = request.id
      ..error = error.message;
  } catch (error) {
    return OutboundMessage_EvaluateResponse()
      ..id = request.id
      ..error = error.toString();
  }
}
