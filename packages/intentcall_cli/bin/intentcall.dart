import 'dart:io';

import 'package:intentcall_cli/src/command_runner.dart';

Future<void> main(final List<String> arguments) async {
  exit(await IntentCallCommandRunner().run(arguments) ?? 64);
}
