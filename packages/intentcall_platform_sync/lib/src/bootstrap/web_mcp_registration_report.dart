/// Outcome of one WebMCP registration attempt.
///
/// [available] is false when the page has no `document.modelContext` or
/// `navigator.modelContext`. That is a skip, not a thrown startup error.
final class WebMcpRegistrationReport {
  const WebMcpRegistrationReport({
    required this.available,
    required this.registered,
    required this.skipped,
  });

  const WebMcpRegistrationReport.unavailable({this.skipped = const <String>[]})
    : available = false,
      registered = const <String>[];

  final bool available;
  final List<String> registered;
  final List<String> skipped;
}
