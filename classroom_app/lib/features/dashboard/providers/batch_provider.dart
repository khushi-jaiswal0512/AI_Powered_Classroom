import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:classroom_app/data/services/api_service.dart';
import '../../../data/models/batch.dart';

// Provides the list of batches the current user is enrolled in
final myBatchesProvider = FutureProvider.autoDispose<List<Batch>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final result = await api.getMyBatches();
  if (result['success'] == true) {
    final list = (result['data'] as List);
    return list.map((e) => Batch.fromJson(e)).toList();
  }
  throw Exception(result['message'] ?? 'Failed to load batches');
});

// Provides all available batches for exploration
final exploreBatchesProvider = FutureProvider.autoDispose<List<Batch>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final result = await api.getAllBatches();
  if (result['success'] == true) {
    final list = (result['data'] as List);
    return list.map((e) => Batch.fromJson(e)).toList();
  }
  throw Exception(result['message'] ?? 'Failed to load explore batches');
});

// Notifier for joining batches
final batchProvider = Provider((ref) => BatchNotifier(ref));

class BatchNotifier {
  final Ref _ref;
  BatchNotifier(this._ref);

  Future<bool> joinBatch(String code) async {
    final api = _ref.read(apiServiceProvider);
    // Ensure code is UPPERCASE as per requirement
    final result = await api.joinBatch(code.toUpperCase());
    if (result['success'] == true) {
      // ✅ Automated Invalidation for Zero-Latency UI
      _ref.invalidate(myBatchesProvider);
      _ref.invalidate(exploreBatchesProvider);
      return true;
    }
    return false;
  }
}

