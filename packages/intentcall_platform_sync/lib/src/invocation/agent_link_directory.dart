import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Address of the process that owns an [AgentInvocationHub].
final class AgentLinkAnnouncement {
  const AgentLinkAnnouncement({
    required this.protocolScheme,
    required this.owner,
    required this.websocket,
    required this.httpInvoke,
    required this.discover,
  });

  factory AgentLinkAnnouncement.fromJson(final Map<String, Object?> json) =>
      AgentLinkAnnouncement(
        protocolScheme: '${json['protocolScheme'] ?? ''}',
        owner: '${json['owner'] ?? ''}',
        websocket: '${json['websocket'] ?? ''}',
        httpInvoke: '${json['httpInvoke'] ?? ''}',
        discover: '${json['discover'] ?? ''}',
      );

  final String protocolScheme;
  final String owner;
  final String websocket;
  final String httpInvoke;
  final String discover;

  Map<String, Object?> toJson() => <String, Object?>{
    'protocolScheme': protocolScheme,
    'owner': owner,
    'websocket': websocket,
    'httpInvoke': httpInvoke,
    'discover': discover,
  };
}

/// Local directory Dart peers use to find a link owner.
///
/// Browsers cannot read this directory. They use [AgentLinkAnnouncement.discover].
final class AgentLinkDirectory {
  AgentLinkDirectory({final Directory? root})
    : root = root ?? AgentLinkDirectory.defaultRoot();

  final Directory root;

  static Directory defaultRoot() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return Directory(p.join(home, '.intentcall', 'links'));
  }

  File fileFor(final String protocolScheme) =>
      File(p.join(root.path, '$protocolScheme.json'));

  Future<void> publish(final AgentLinkAnnouncement announcement) async {
    await root.create(recursive: true);
    final file = fileFor(announcement.protocolScheme);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      '${jsonEncode(announcement.toJson())}\n',
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<void> remove(final String protocolScheme) async {
    final file = fileFor(protocolScheme);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Returns the record only when `GET /agent/discover` answers the same scheme.
  Future<AgentLinkAnnouncement?> find(final String protocolScheme) async {
    final file = fileFor(protocolScheme);
    if (!file.existsSync()) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on Object {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }
    final announcement = AgentLinkAnnouncement.fromJson(
      Map<String, Object?>.from(decoded),
    );
    if (announcement.protocolScheme != protocolScheme) {
      return null;
    }
    final live = await _discoverLive(announcement.discover);
    if (live == null || live.protocolScheme != protocolScheme) {
      return null;
    }
    return live;
  }

  Future<AgentLinkAnnouncement?> _discoverLive(final String url) async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(milliseconds: 400));
      final response = await request.close().timeout(
        const Duration(milliseconds: 400),
      );
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }
      final raw = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return AgentLinkAnnouncement.fromJson(Map<String, Object?>.from(decoded));
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
