import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Bounds demo-audio storage on low-cost devices.
class AudioCacheService {
  static const maxCachedFiles = 8;

  Future<void> trimDemoAudioCache() async {
    final directory = await getTemporaryDirectory();
    final files = await directory
        .list()
        .where((entity) => entity is File && p.basename(entity.path).startsWith('eduvaani_santali_demo_'))
        .cast<File>()
        .toList();
    if (files.length <= maxCachedFiles) return;
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    for (final file in files.take(files.length - maxCachedFiles)) {
      await file.delete();
    }
  }
}
