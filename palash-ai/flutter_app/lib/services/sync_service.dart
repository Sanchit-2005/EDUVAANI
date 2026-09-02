import 'dart:convert';
import 'dart:io';

import '../models/sync_status.dart';
import '../repositories/sync_repository.dart';

class SyncService {
  SyncService({SyncRepository? repository}) : _repository = repository ?? SyncRepository();

  final SyncRepository _repository;

  Future<SyncStatus> sync(String baseUrl) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/sync'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'requestedAt': DateTime.now().toIso8601String()}));
      final response = await request.close();
      if (response.statusCode != 200) throw HttpException('Sync server returned ${response.statusCode}.');
      final decoded = jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final status = SyncStatus(
        lastSyncedAt: DateTime.now(),
        downloadedLessons: (data['lessons'] as List).length,
        downloadedTranslations: (data['translations'] as List).length,
        downloadedModels: (data['models'] as List).length,
      );
      await _repository.saveDownloadedContent(
        lessons: (data['lessons'] as List).cast<Map<String, dynamic>>(),
        translations: (data['translations'] as List).cast<Map<String, dynamic>>(),
        status: status,
      );
      return status;
    } finally {
      client.close(force: true);
    }
  }
}
