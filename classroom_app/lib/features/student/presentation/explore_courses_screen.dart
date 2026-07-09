import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/batch_card.dart';
import '../../dashboard/providers/batch_provider.dart';

class ExploreCoursesScreen extends ConsumerWidget {
  const ExploreCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchState = ref.watch(exploreBatchesProvider); 

    return Scaffold(
      backgroundColor: const Color(0xFF12141D), 
      appBar: AppBar(
        title: const Text('Explore Courses'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Batches',
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold, 
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join a course to start your learning journey',
              style: TextStyle(
                fontSize: 14, 
                color: Colors.white.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: batchState.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF))),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text('Error loading batches: $err', style: const TextStyle(color: Colors.redAccent)),
                      TextButton(
                        onPressed: () => ref.invalidate(exploreBatchesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (batches) {
                  if (batches.isEmpty) {
                    return const Center(child: Text('No batches available at the moment.', style: TextStyle(color: Colors.white54)));
                  }
                  return GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : (MediaQuery.of(context).size.width > 800 ? 3 : (MediaQuery.of(context).size.width > 500 ? 2 : 1)), 
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: batches.length,
                    itemBuilder: (context, index) {
                      return BatchCard(batch: batches[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
