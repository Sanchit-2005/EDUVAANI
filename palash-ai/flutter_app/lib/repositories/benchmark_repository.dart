import '../database/database_helper.dart';
import '../models/latency_benchmark.dart';

class BenchmarkRepository {
  Future<void> save(LatencyBenchmark benchmark) async {
    final database = await DatabaseHelper.instance.database;
    await database.insert(DatabaseHelper.benchmarkTable, benchmark.toMap());
  }
}
