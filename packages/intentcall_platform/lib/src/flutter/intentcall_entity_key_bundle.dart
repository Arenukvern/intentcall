/// Manifest-projected entity field keys for native snapshot channels.
final class IntentCallEntityKeyBundle {
  const IntentCallEntityKeyBundle({
    this.idKey = 'id',
    this.titleKey = 'title',
    this.subtitleKey = 'subtitle',
    this.keywordsKey = 'keywords',
  });

  final String idKey;
  final String titleKey;
  final String subtitleKey;
  final String keywordsKey;
}

IntentCallEntityKeyBundle intentCallDefaultEntityKeyBundle() =>
    const IntentCallEntityKeyBundle();
