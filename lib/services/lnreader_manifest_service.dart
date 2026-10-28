import 'dart:convert';

import '../models/lnreader_manifest_entry.dart';
import 'lnreader_http_client.dart';

class LnReaderManifestFetchResult {
  const LnReaderManifestFetchResult({
    this.manifest,
    this.error,
    this.statusCode,
    this.uri,
  });

  final LnReaderManifest? manifest;
  final String? error;
  final int? statusCode;
  final Uri? uri;

  bool get isSuccess => manifest != null;
}

class LnReaderManifestParseException implements Exception {
  const LnReaderManifestParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LnReaderManifestService {
  LnReaderManifestService({required this.httpClient});

  static final Uri manifestUri = Uri.parse(
    'https://raw.githubusercontent.com/LNReader/lnreader-plugins/plugins/'
    'v3.0.0/.dist/plugins.min.json',
  );

  final LnReaderHttpClient httpClient;

  Future<LnReaderManifestFetchResult> fetch({Uri? uri}) async {
    final target = uri ?? manifestUri;
    try {
      final response = await httpClient.get(target);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return LnReaderManifestFetchResult(
          statusCode: response.statusCode,
          uri: response.uri,
          error: 'Manifest request returned HTTP ${response.statusCode}.',
        );
      }

      final manifest = parseManifest(response.body);
      return LnReaderManifestFetchResult(
        manifest: manifest,
        statusCode: response.statusCode,
        uri: response.uri,
      );
    } on LnReaderHttpException catch (error) {
      return LnReaderManifestFetchResult(uri: target, error: error.message);
    } on LnReaderManifestParseException catch (error) {
      return LnReaderManifestFetchResult(uri: target, error: error.message);
    } catch (error) {
      return LnReaderManifestFetchResult(
        uri: target,
        error: 'Could not retrieve the manifest: $error',
      );
    }
  }
}

LnReaderManifest parseManifest(String body) {
  if (body.trim().isEmpty) {
    throw const LnReaderManifestParseException('The manifest was empty.');
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (error) {
    throw LnReaderManifestParseException(
      'The manifest is not valid JSON: ${error.message}',
    );
  }

  if (decoded is! List) {
    throw const LnReaderManifestParseException(
      'The manifest root must be a JSON array.',
    );
  }

  final entries = <LnReaderManifestEntry>[];
  final issues = <LnReaderManifestIssue>[];

  for (var index = 0; index < decoded.length; index++) {
    final raw = decoded[index];
    if (raw is! Map) {
      issues.add(
        LnReaderManifestIssue(
          index: index,
          message: 'Entry is not a JSON object.',
        ),
      );
      continue;
    }

    try {
      entries.add(
        LnReaderManifestEntry.fromJson(
          raw.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value),
          ),
        ),
      );
    } on FormatException catch (error) {
      final id = raw['id'];
      final label = id is String && id.trim().isNotEmpty ? ' ($id)' : '';
      issues.add(
        LnReaderManifestIssue(
          index: index,
          message: 'Entry $index$label: ${error.message}',
        ),
      );
    }
  }

  return LnReaderManifest(
    entries: entries,
    issues: issues,
    totalEntries: decoded.length,
  );
}
