Classes that implement the [visitor pattern] for traversing the Sass [AST].
Callers can either implement interfaces like [`StatementVisitor`] from scratch
to handle *all* Sass node types, or extend helper classes like
[`RecursiveStatementVisitor`] which traverse the entire AST to handle only
specific nodes.

[visitor pattern]: https://en.wikipedia.org/wiki/Visitor_pattern
[AST]: AST-topic.html
[`StatementVisitor`]: ../sass/StatementVisitor-class.html
[`RecursiveStatementVisitor`]: ../sass/RecursiveStatementVisitor-class.html
