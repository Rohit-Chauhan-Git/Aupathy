/// One entry from the official LNReader plugin manifest.
///
/// This is a transport/diagnostic model only. It is never written to Hive.
class LnReaderManifestEntry {
  const LnReaderManifestEntry({
    required this.id,
    required this.name,
    required this.site,
    required this.lang,
    required this.version,
    required this.url,
    this.iconUrl,
  });

  factory LnReaderManifestEntry.fromJson(Map<String, dynamic> json) {
    final id = _requiredString(json, 'id');
    final name = _requiredString(json, 'name');
    final site = _requiredString(json, 'site');
    final lang = _requiredString(json, 'lang');
    final version = _requiredString(json, 'version');
    final url = _requiredString(json, 'url');

    _validateHttpUrl(site, 'site');
    _validateHttpUrl(url, 'url');

    final iconUrl = json['iconUrl'];
    if (iconUrl != null && iconUrl is! String) {
      throw const FormatException('iconUrl must be a string when present.');
    }

    return LnReaderManifestEntry(
      id: id,
      name: name,
      site: site,
      lang: lang,
      version: version,
      url: url,
      iconUrl: iconUrl as String?,
    );
  }

  final String id;
  final String name;
  final String site;
  final String lang;
  final String version;
  final String url;
  final String? iconUrl;

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('"$key" must be a non-empty string.');
    }
    return value.trim();
  }

  static void _validateHttpUrl(String value, String key) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw FormatException('"$key" must be a valid http(s) URL.');
    }
  }
}

class LnReaderManifestIssue {
  const LnReaderManifestIssue({required this.index, required this.message});

  final int index;
  final String message;
}

class LnReaderManifest {
  const LnReaderManifest({
    required this.entries,
    required this.issues,
    required this.totalEntries,
  });

  final List<LnReaderManifestEntry> entries;
  final List<LnReaderManifestIssue> issues;
  final int totalEntries;

  int get invalidCount => issues.length;
  int get validCount => entries.length;
}
