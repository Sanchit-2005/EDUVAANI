import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/database_helper.dart';

/// Desktop sqflite uses FFI; Android/iOS use the native plugin.
Future<void> configureDatabaseFactory() async {
  if (kIsWeb) return;
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

Future<void> initializeLocalDatabase() async {
  await configureDatabaseFactory();
  await DatabaseHelper.instance.database;
}
