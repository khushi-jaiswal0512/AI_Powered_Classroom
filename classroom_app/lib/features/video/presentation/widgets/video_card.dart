import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import 'package:classroom_app/data/services/api_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/video_library_provider.dart';

class VideoCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> videoData;
  final VoidCallback onRefresh;

  const VideoCard({
    super.key,
    required this.videoData,
    required this.onRefresh,
  });

  @override
  ConsumerState<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends ConsumerState<VideoCard> {
  bool? _quizExists;
  bool _isGenerating = false;
  bool _isDownloading = false;

  String get videoId => widget.videoData['id'].toString();
  String get title => widget.videoData['title'] ?? 'Untitled Video';
  String get teacherName => widget.videoData['teacherName'] ?? 'Unknown Teacher';
  String get createdAt => widget.videoData['createdAt'] ?? 'N/A';
  
  // 🔥 FIX: Check the actual 'transcript' field from the API to determine if processing is done.
  bool get isPending {
    final transcript = widget.videoData['transcript'];
    return transcript == null || transcript.toString().trim().isEmpty;
  }

  @override
  void initState() {
    super.initState();
    _checkQuiz();
  }

  @override
  void didUpdateWidget(VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check if the transcript status changed
    final oldTranscript = oldWidget.videoData['transcript'];
    final newTranscript = widget.videoData['transcript'];
    if (oldTranscript != newTranscript) {
      _checkQuiz();
    }
  }

  Future<void> _checkQuiz() async {
    if (!isPending) {
      try {
        final api = ref.read(apiServiceProvider);
        final exists = await api.checkQuizExists(int.parse(videoId));
        if (mounted) setState(() => _quizExists = exists);
      } catch (e) {
        if (mounted) setState(() => _quizExists = false);
      }
    }
  }

  Future<void> _handleDownload() async {
    setState(() => _isDownloading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.getVideoDownloadUrl(videoId);
      
      if (result['success'] == true) {
        final data = result['data'];
        final url = data['url'] ?? data['downloadUrl'];
        if (url != null) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: ${result['message']}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _handleGenerateQuiz() async {
    setState(() => _isGenerating = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating Quiz... Please wait.')),
    );

    try {
      final api = ref.read(apiServiceProvider);
      debugPrint('Generating quiz for videoId: $videoId');
      final result = await api.generateQuiz(int.parse(videoId));
      
      if (result['success'] == true) {
        // Immediately check for existence to update UI
        final exists = await api.checkQuizExists(int.parse(videoId));
        
        if (mounted) {
          setState(() => _quizExists = exists);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quiz generated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onRefresh();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Quiz generation failed: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Quiz generation failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quiz generation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = ref.watch(authProvider).role == 'TEACHER';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPending ? Icons.hourglass_empty : Icons.video_library,
                  color: isPending ? Colors.orange : AppColors.primary,
                  size: 40,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('By: $teacherName', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                      Text('Uploaded: $createdAt', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60)),
                    ],
                  ),
                ),
              ],
            ),
            if (isPending)
              const Padding(
                padding: EdgeInsets.only(top: 12.0),
                child: Row(
                  children: [
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent)),
                    SizedBox(width: 8),
                    Text('Processing AI Transcript...', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (!isPending) ...[
                  ElevatedButton.icon(
                    onPressed: () => context.push('/video/player/$videoId'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  ),
                  _buildQuizButton(isTeacher),
                ],
                ElevatedButton.icon(
                  onPressed: _isDownloading ? null : _handleDownload,
                  icon: _isDownloading 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download),
                  label: const Text('Download'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuizButton(bool isTeacher) {
    if (isPending) {
      return const SizedBox.shrink();
    }

    if (_quizExists == null) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (!_quizExists!) {
      if (!isTeacher) return const SizedBox.shrink();

      return ElevatedButton.icon(
        onPressed: _isGenerating ? null : _handleGenerateQuiz,
        icon: _isGenerating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.stars, color: Colors.amber), // ⭐ icon
        label: const Text('Generate Quiz'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => context.push('/quiz/$videoId'),
      icon: const Icon(Icons.play_circle_filled), // ▶ icon
      label: const Text('View Quiz'),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
    );
  }
}