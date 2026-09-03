import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../database/database_helper.dart';
import '../../models/scan_result.dart';
import '../../repositories/scan_repository.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  late final ScanRepository _repository;
  late Future<List<ScanResult>> _future;

  @override
  void initState() {
    super.initState();
    _repository = ScanRepository(DatabaseHelper.instance);
    _future = _repository.getAllScans();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repository.getAllScans();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        backgroundColor: AppColors.primary,
      ),
      body: FutureBuilder<List<ScanResult>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading scans: ${snapshot.error}'),
            );
          }

          final scans = snapshot.data ?? const <ScanResult>[];

          if (scans.isEmpty) {
            return const Center(child: Text('No scan history yet'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: scans.length,
              itemBuilder: (context, index) {
                final scan = scans[index];
                final createdAt =
                    DateTime.tryParse(scan.createdAt ?? '') ?? DateTime.now();
                final dateText = DateFormat('MMM dd, yyyy · hh:mm a')
                    .format(createdAt);

                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateText,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Santali: ${scan.santaliText}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Hindi: ${scan.hindiTranslation}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Scan Details'),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Santali: ${scan.santaliText}',
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.md,
                                            ),
                                            Text(
                                              'Hindi: ${scan.hindiTranslation}',
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.visibility_rounded),
                                label: const Text('View'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () async {
                                  await _repository.deleteScan(scan.id!);
                                  _refresh();
                                },
                                icon: const Icon(Icons.delete_rounded),
                                label: const Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
