import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../video/providers/video_library_provider.dart';
import '../../../live_class/providers/live_class_provider.dart';
import '../../../ai_chat/presentation/chat_screen.dart';
import 'package:classroom_app/data/services/api_service.dart';
import 'package:go_router/go_router.dart';

/// 🎥 VIDEOS VIEW
class BatchVideosView extends ConsumerWidget {
  final int batchId;
  const BatchVideosView({super.key, required this.batchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We use a FutureProvider to fetch videos specifically for this batch
    final videosState = ref.watch(batchVideosProvider(batchId));

    return videosState.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF))),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
      data: (videos) {
        if (videos.isEmpty) {
          return const Center(child: Text('No videos uploaded for this batch.', style: TextStyle(color: Colors.white54)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const Icon(Icons.play_circle_fill, color: Color(0xFF6B4EFF), size: 40),
              title: Text(video.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Added on: ${video.createdAt}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white24),
              onTap: () => context.push('/video/player/${video.id}'),
            );
          },
        );
      },
    );
  }
}

/// 🧠 QUIZZES VIEW (✅ UPDATED FOR STUDENTS)
class BatchQuizzesView extends ConsumerWidget {
  final int batchId;
  const BatchQuizzesView({super.key, required this.batchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We fetch the videos for the batch to check which ones have active quizzes
    final videosState = ref.watch(batchVideosProvider(batchId));

    return videosState.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF))),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
      data: (videos) {
        if (videos.isEmpty) {
          return const Center(
            child: Text(
              'No quizzes available for this batch yet.', 
              style: TextStyle(color: Colors.white54)
            )
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            // Render a smart tile that only shows up if a quiz exists
            return _StudentQuizTile(video: video);
          },
        );
      },
    );
  }
}

// ✅ NEW: Diagnostic Quiz Tile that visibly shows exactly what state the quiz is in
class _StudentQuizTile extends ConsumerStatefulWidget {
  final dynamic video; // Inherits the VideoItem model from the provider
  const _StudentQuizTile({required this.video});

  @override
  ConsumerState<_StudentQuizTile> createState() => _StudentQuizTileState();
}

class _StudentQuizTileState extends ConsumerState<_StudentQuizTile> {
  bool? _quizExists;

  @override
  void initState() {
    super.initState();
    _checkQuizAvailability();
  }

  Future<void> _checkQuizAvailability() async {
    try {
      final api = ref.read(apiServiceProvider);
      // 🔥 THE FIX: api_service strictly expects a String here, NOT an int.
      // widget.video.id.toString() passes the exact String format it needs.
      final exists = await api.checkQuizExists(int.parse(widget.video.id.toString()));
      
      if (mounted) setState(() => _quizExists = exists);
    } catch (e) {
      debugPrint("Quiz Check Error: $e");
      if (mounted) setState(() => _quizExists = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Loading State: Checking API
    if (_quizExists == null) {
      return Card(
        color: const Color(0xFF1E202C),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const ListTile(
          leading: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6B4EFF))),
          title: Text('Checking available quizzes...', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ),
      );
    }

    // 2. Hidden State: Teacher hasn't generated it yet
    if (!_quizExists!) {
      return Card(
        color: const Color(0xFF1E202C).withOpacity(0.5),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: const Icon(Icons.lock_clock, color: Colors.white24),
          title: Text(widget.video.title.toString(), style: const TextStyle(color: Colors.white54)),
          subtitle: const Text('Quiz not generated by teacher yet', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      );
    }

    // 3. Active State: Quiz is available!
    return Card(
      color: const Color(0xFF1E202C),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amberAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)
          ),
          child: const Icon(Icons.psychology_rounded, color: Colors.amberAccent, size: 28),
        ),
        title: Text(
          'Quiz: ${widget.video.title}', 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Text(
            'Test your knowledge on this topic', 
            style: TextStyle(color: Colors.white54, fontSize: 12)
          ),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B4EFF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: () => context.push('/quiz/${widget.video.id}'),
          child: const Text('Attempt', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

/// 📡 LIVE CLASSES VIEW
class BatchLiveClassesView extends ConsumerStatefulWidget {
  final int batchId;
  const BatchLiveClassesView({super.key, required this.batchId});

  @override
  ConsumerState<BatchLiveClassesView> createState() => _BatchLiveClassesViewState();
}

class _BatchLiveClassesViewState extends ConsumerState<BatchLiveClassesView> {
  @override
  void initState() {
    super.initState();
    // Fetch live classes filtered for this batch
    Future.microtask(() => ref.read(liveClassesProvider.notifier).fetchClasses(batchId: widget.batchId));
  }

  @override
  Widget build(BuildContext context) {
    final liveState = ref.watch(liveClassesProvider);

    return liveState.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF))),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
      data: (classes) {
        if (classes.isEmpty) {
          return const Center(child: Text('No live classes scheduled.', style: TextStyle(color: Colors.white54)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final liveClass = classes[index];
            return Card(
              color: const Color(0xFF1E202C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: liveClass.isLive ? Colors.red : Colors.grey,
                  radius: 6,
                ),
                title: Text(liveClass.title, style: const TextStyle(color: Colors.white)),
                subtitle: Text(liveClass.isLive ? 'LIVE NOW' : 'Scheduled', 
                  style: TextStyle(color: liveClass.isLive ? Colors.redAccent : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4EFF)),
                  onPressed: () => context.push('/live_stream/${liveClass.id}'),
                  child: const Text('Join'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 🤖 AI DOUBT SOLVER VIEW
class AIDoubtSolverView extends ConsumerWidget {
  final int batchId;
  const AIDoubtSolverView({super.key, required this.batchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now, we reuse the ChatScreen component but pass the batchId context
    return const ChatScreen(); 
  }
}

/// 💉 PROVIDERS FOR BATCH CONTENT
final batchVideosProvider = FutureProvider.family<List<VideoItem>, int>((ref, batchId) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.getVideosByBatch(batchId);
  
  List<dynamic> list = [];
  if (response is List) {
    list = response;
  } else if (response is Map) {
    final data = response['data'] ?? response['videos'] ?? response;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = data['videos'] ?? data['data'] ?? [];
    }
  }
  
  return list
      .whereType<Map>()
      .map((e) => VideoItem.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});
