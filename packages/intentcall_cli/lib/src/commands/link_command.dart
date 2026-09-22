import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_platform_sync/io.dart';

final class LinkCommand extends Command<int> {
  LinkCommand() {
    addSubcommand(LinkDiscoverCommand());
    addSubcommand(LinkCallCommand());
  }

  @override
  String get name => 'link';

  @override
  String get description =>
      'Find a local IntentCall owner and call one of its tools.';
}

final class LinkDiscoverCommand extends Command<int> {
  @override
  String get name => 'discover';

  @override
  String get description => 'Print the live link announcement for a scheme.';

  @override
  Future<int> run() async {
    final scheme = _scheme(argResults);
    if (scheme == null) {
      return 64;
    }
    final found = await _directory(argResults).find(scheme);
    if (found == null) {
      stderr.writeln('No live IntentCall link for scheme "$scheme".');
      return 1;
    }
    stdout.writeln(jsonEncode(found.toJson()));
    return 0;
  }

  @override
  ArgParser get argParser => _parser();
}

final class LinkCallCommand extends Command<int> {
  @override
  String get name => 'call';

  @override
  String get description => 'Invoke a tool on the discovered link owner.';

  @override
  Future<int> run() async {
    final results = argResults!;
    final scheme = _scheme(results);
    final name = '${results['name'] ?? ''}'.trim();
    if (scheme == null || name.isEmpty) {
      stderr.writeln('Required: --scheme and --name.');
      return 64;
    }
    final found = await _directory(results).find(scheme);
    if (found == null) {
      stderr.writeln('No live IntentCall link for scheme "$scheme".');
      return 1;
    }
    final Object? arguments = jsonDecode('${results['args'] ?? '{}'}');
    if (arguments is! Map) {
      stderr.writeln('--args must be a JSON object.');
      return 64;
    }
    final result = await invokeAgentWebSocket(
      uri: Uri.parse(found.websocket),
      envelope: IntentCallInvocationEnvelope(
        id: 'cli-${DateTime.now().microsecondsSinceEpoch}',
        qualifiedName: name,
        arguments: Map<String, Object?>.from(arguments),
        source: IntentCallInvocationSource.websocket,
      ),
    );
    stdout.writeln(
      jsonEncode(
        AgentCallObservation(
          envelope: IntentCallInvocationEnvelope(
            id: 'cli',
            qualifiedName: name,
            arguments: const <String, Object?>{},
            source: IntentCallInvocationSource.websocket,
          ),
          result: result,
        ).toJson()['result'],
      ),
    );
    return result.ok ? 0 : 1;
  }

  @override
  ArgParser get argParser => _parser()
    ..addOption('name', help: 'Qualified tool name.')
    ..addOption('args', help: 'JSON object of arguments.', defaultsTo: '{}');
}

ArgParser _parser() => ArgParser()
  ..addOption('scheme', help: 'Protocol scheme of the link owner.')
  ..addOption('directory', help: 'Override the link directory.');

String? _scheme(final ArgResults? results) {
  final scheme = '${results?['scheme'] ?? ''}'.trim();
  if (scheme.isEmpty) {
    stderr.writeln('Required: --scheme.');
    return null;
  }
  return scheme;
}

AgentLinkDirectory _directory(final ArgResults? results) {
  final override = '${results?['directory'] ?? ''}'.trim();
  if (override.isEmpty) {
    return AgentLinkDirectory();
  }
  return AgentLinkDirectory(root: Directory(override));
}
