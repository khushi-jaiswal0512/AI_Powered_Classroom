import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/batch_provider.dart';

class MyBatchesScreen extends ConsumerWidget {
  const MyBatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchState = ref.watch(myBatchesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF12141D),
      appBar: AppBar(
        title: const Text('My Enrolled Batches'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: batchState.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF))),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
        data: (batches) {
          if (batches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school_outlined, color: Colors.white24, size: 64),
                  const SizedBox(height: 16),
                  const Text('You haven\'t joined any batches yet.', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/explore'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4EFF)),
                    child: const Text('Explore Courses'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            itemBuilder: (context, index) {
              final batch = batches[index];
              return Card(
                color: const Color(0xFF1E202C),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.class_, color: Color(0xFF6B4EFF), size: 32),
                  title: Text(batch.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(batch.subject, style: const TextStyle(color: Colors.white54)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                  onTap: () => context.push('/batch/${batch.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
