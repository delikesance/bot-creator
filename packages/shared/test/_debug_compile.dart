import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'dart:convert';

void main() {
  final result = BdfdCompiler().compile(
    r'Has Users perms : $checkUserPerms[$authorID;manageserver]',
  );
  print('Errors: ${result.hasErrors}');
  for (final d in result.diagnostics) {
    print('  ${d.severity}: ${d.message}');
  }
  print('Actions (${result.actions.length}):');
  print(
    const JsonEncoder.withIndent(
      '  ',
    ).convert(result.actions.map((a) => a.toJson()).toList()),
  );
}
