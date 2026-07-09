import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import 'package:classroom_app/data/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

// 🔥 FIX: batch-aware provider (fallback to all videos)
final videoListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);

  dynamic result;
  try {
    result = await api.getAllVideos();
  } catch (_) {
    result = [];
  }

  List list = [];
  if (result is List) {
    list = result;
  } else if (result is Map) {
    final data = result['data'] ?? result['videos'] ?? result;
    if (data is List) list = data;
  }

  return list
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
});

class VideoListScreen extends ConsumerStatefulWidget {
  const VideoListScreen({super.key});

  @override
  ConsumerState<VideoListScreen> createState() =>
      _VideoListScreenState();
}

class _VideoListScreenState
    extends ConsumerState<VideoListScreen> {

  Future<void> _handleDownload(
    BuildContext context,
    String videoId,
    ApiService api,
  ) async {
    try {
      final response = await api.getVideoDownloadUrl(videoId);

      if (response['success'] != true) {
        throw Exception(response['message']);
      }

      final data = response['data'];

      String? downloadUrl =
          data is Map ? (data['downloadUrl'] ?? data['url']) : null;

      if (downloadUrl == null || downloadUrl.isEmpty) {
        throw Exception("Download URL missing");
      }

      downloadUrl = downloadUrl
          .replaceAll("\n", "")
          .replaceAll("\r", "")
          .trim();

      print("🎯 FINAL DOWNLOAD URL: $downloadUrl");

      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception("Could not launch $downloadUrl");
      }

    } catch (e) {
      print("🔥 DOWNLOAD ERROR: $e");

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoListProvider);
    final isTeacher = ref.watch(authProvider).role == 'TEACHER';
    final api = ref.read(apiServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Course Videos'),
        backgroundColor: Colors.transparent,
      ),
      body: videoState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (videos) {
          if (videos.isEmpty)
            return const Center(child: Text('No videos found.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              final String id = video['id'].toString();

              // ✅ PRIMARY: transcript field is the truth — if null, still processing
              final bool hasTranscript = video['transcript'] != null &&
                  video['transcript'].toString().isNotEmpty;

              // FALLBACK: also accept transcriptionStatus == COMPLETED
              final String status =
                  (video['transcriptionStatus'] ?? '')
                      .toString()
                      .toUpperCase();
              final bool statusCompleted = status == 'COMPLETED';

              // Ready when either transcript exists or status says COMPLETED
              final bool isPending = !hasTranscript && !statusCompleted;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPending
                                ? Icons.hourglass_empty
                                : Icons.video_library,
                            color: isPending
                                ? Colors.orange
                                : AppColors.primary,
                            size: 40,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  video['title'] ?? 'Untitled',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'By: ${video['teacherName'] ?? "Unknown Teacher"}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                                if ((video['batchName'] ?? '').toString().isNotEmpty)
                                  Text(
                                    'Batch: ${video['batchName']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.white60),
                                  ),
                                Text(
                                  // ✅ FIX: backend sends 'uploadedAt', not 'createdAt'
                                  'Uploaded: ${video['uploadedAt'] ?? video['createdAt'] ?? 'N/A'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.white60),
                                ),
                                if (isPending)
                                  const Padding(
                                    padding:
                                        EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Processing AI Transcript...',
                                      style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.border),
                      Wrap(
                        spacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          // ✅ Teacher: show Trigger Transcription when still pending
                          if (isPending && isTeacher)
                            ElevatedButton.icon(
                              onPressed: () async {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Triggering transcription...')),
                                );
                                try {
                                  await api.generateTranscript(id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Transcription started! Refresh in a moment.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                  ref.invalidate(videoListProvider);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.transcribe),
                              label: const Text('Trigger Transcription'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                            ),
                          if (!isPending) ...[
                            ElevatedButton.icon(
                              onPressed: () =>
                                  context.push('/video/player/$id'),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Play'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppColors.success,
                              ),
                            ),
                            _QuizButton(
                              videoId: id,
                              isTeacher: isTeacher,
                              api: api,
                            ),
                          ],
                          ElevatedButton.icon(
                            onPressed: () =>
                                _handleDownload(context, id, api),
                            icon: const Icon(Icons.download),
                            label: const Text('Download'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: (100 * index).ms)
                  .slideY(begin: 0.1);
            },
          );
        },
      ),
    );
  }
}

// ================= QUIZ BUTTON =================

class _QuizButton extends StatefulWidget {
  final String videoId;
  final bool isTeacher;
  final ApiService api;

  const _QuizButton({
    required this.videoId,
    required this.isTeacher,
    required this.api,
  });

  @override
  State<_QuizButton> createState() => _QuizButtonState();
}

class _QuizButtonState extends State<_QuizButton> {
  bool? _quizExists;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _checkQuiz();
  }

  Future<void> _checkQuiz() async {
    if (!mounted) return;
    setState(() => _quizExists = null); // show loading

    try {
      final res = await widget.api.getQuizForVideo(widget.videoId);

      bool exists = false;

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        // Handle both flat {questions:[]} and nested {data:{questions:[]}}
        final questions = (data is Map)
            ? (data['questions'] ?? data['data']?['questions'])
            : null;
        exists = questions is List && questions.isNotEmpty;
      }

      if (mounted) setState(() => _quizExists = exists);
    } catch (_) {
      if (mounted) setState(() => _quizExists = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_quizExists == null) {
      return const SizedBox(
        width: 44,
        height: 36,
        child: Center(child: SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )),
      );
    }

    // Teacher layout: separate buttons if transcribed
    if (widget.isTeacher) {
      return Wrap(
        spacing: 8,
        children: [
          // 1. Generate Quiz (Always visible for Teacher)
          ElevatedButton.icon(
            onPressed: _isGenerating
                ? null
                : () async {
                    setState(() => _isGenerating = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Generating Quiz...')),
                    );
                    try {
                      final parsedId = num.tryParse(widget.videoId)?.toInt();
                      if (parsedId == null) {
                        throw Exception("Invalid Video ID: ${widget.videoId}");
                      }
                      final result = await widget.api.generateQuiz(parsedId);
                      if (result['success'] != true) {
                        throw Exception(result['message'] ?? 'Quiz generation failed');
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Quiz generated!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                      await _checkQuiz();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Quiz failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isGenerating = false);
                    }
                  },
            icon: _isGenerating
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.stars, color: Colors.amber),
            label: const Text('Generate Quiz'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
          ),
          
          // 2. View Quiz (Visible only if quiz exists)
          if (_quizExists!)
            ElevatedButton.icon(
              onPressed: () => context.push('/quiz/${widget.videoId}'),
              icon: const Icon(Icons.play_circle_filled),
              label: const Text('View Quiz'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
        ],
      );
    }

    // Student layout: show ONLY "View Quiz" and only if it exists
    if (_quizExists!) {
      return ElevatedButton.icon(
        onPressed: () => context.push('/quiz/${widget.videoId}'),
        icon: const Icon(Icons.play_circle_filled),
        label: const Text('View Quiz'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
      );
    }

    return const SizedBox.shrink();
  }
}
