import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:classroom_app/data/services/api_service.dart';

class VideoItem {
  final String id;
  final String title;
  final String? url;
  final String? teacherName;
  final String createdAt;
  final String transcriptionStatus;
  final String? transcript;
  final bool hasQuiz;

  VideoItem({
    required this.id,
    required this.title,
    this.url,
    this.teacherName,
    required this.createdAt,
    this.transcriptionStatus = 'Pending',
    this.transcript,
    this.hasQuiz = false,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: json['id'].toString(),
      title: json['title'] ?? 'Untitled Video',
      url: json['url'],
      teacherName: json['teacherName'],
      // ✅ FIX: backend VideoDTO uses 'uploadedAt', not 'createdAt'
      createdAt: json['uploadedAt'] ?? json['createdAt'] ?? '',
      transcriptionStatus: json['transcriptionStatus'] ?? 'Pending',
      transcript: json['transcript'],
    );
  }

  VideoItem copyWith({
    String? id,
    String? title,
    String? url,
    String? teacherName,
    String? createdAt,
    String? transcriptionStatus,
    String? transcript,
    bool? hasQuiz,
  }) {
    return VideoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      teacherName: teacherName ?? this.teacherName,
      createdAt: createdAt ?? this.createdAt,
      transcriptionStatus: transcriptionStatus ?? this.transcriptionStatus,
      transcript: transcript ?? this.transcript,
      hasQuiz: hasQuiz ?? this.hasQuiz,
    );
  }
}

final videoLibraryProvider =
    NotifierProvider<VideoLibraryNotifier, AsyncValue<List<VideoItem>>>(
      VideoLibraryNotifier.new,
    );

class VideoLibraryNotifier extends Notifier<AsyncValue<List<VideoItem>>> {
  ApiService get _apiService => ref.read(apiServiceProvider);
  int? _selectedBatchId;

  int? get selectedBatchId => _selectedBatchId;

  @override
  AsyncValue<List<VideoItem>> build() {
    fetchVideos();
    return const AsyncValue.loading();
  }

  Future<void> fetchVideos({int? batchId}) async {
    _selectedBatchId = batchId;
    state = const AsyncValue.loading();

    try {
      dynamic response = batchId != null
          ? await _apiService.getVideosByBatch(batchId)
          : await _apiService.getMyVideos();

      if (batchId == null && response is List && response.isEmpty) {
        response = await _apiService.getAllVideos();
      }

      dev.log('Video fetch response: $response', name: 'VideoLibrary');

      List list = [];

      if (response is List) {
        list = response;
      } else if (response is Map) {
        final data = response['data'];

        if (data is List) {
          list = data;
        } else if (data is Map) {
          if (data['videos'] is List) {
            list = data['videos'];
          } else {
            list = data.values.firstWhere(
              (v) => v is List,
              orElse: () => [],
            );
          }
        }
      }

      final videos = list
          .whereType<Map>()
          .map((e) => VideoItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final updatedVideos = await Future.wait(videos.map((v) async {
        // ✅ Use transcript field as primary truth (matches VideoDTO logic)
        final bool isReady = (v.transcript != null && v.transcript!.isNotEmpty)
            || v.transcriptionStatus.toUpperCase() == 'COMPLETED';

        if (isReady) {
          try {
            // ✅ FIX: use getQuizForVideo directly (checkQuizExists had wrong URL prefix)
            final res = await _apiService.getQuizForVideo(v.id);
            bool hasQuiz = false;
            if (res['success'] == true && res['data'] != null) {
              final data = res['data'];
              final questions = (data is Map)
                  ? (data['questions'] ?? data['data']?['questions'])
                  : null;
              hasQuiz = questions is List && questions.isNotEmpty;
            }
            return v.copyWith(hasQuiz: hasQuiz);
          } catch (_) {
            return v;
          }
        }
        return v;
      }));

      state = AsyncValue.data(updatedVideos);

    } catch (e) {

      // ✅ FIX 2: removed silent failure
      state = AsyncValue.error(e, StackTrace.current);

      dev.log('Error fetching videos: $e', name: 'VideoLibrary');
    }
  }

  Future<bool> triggerTranscription(String videoId) async {
    try {
      await _apiService.generateTranscript(videoId);
      await fetchVideos(); // Refresh list to show updated status
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getDownloadUrl(String videoId) async {
    try {
      final response = await _apiService.getVideoDownloadUrl(videoId);

      final data = response['data'];

      if (data is Map) {
        return data['downloadUrl'];
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> generateQuiz(String videoId) async {
    try {
      final parsedId = num.tryParse(videoId)?.toInt();
      if (parsedId == null) throw Exception('Invalid video ID: $videoId');

      final response = await _apiService.generateQuiz(parsedId);
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Quiz generation failed');
      }
      await fetchVideos(batchId: _selectedBatchId);
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// ✅ Added: Specific provider for fetching playable URLs
final videoPlaybackProvider = FutureProvider.family<String, String>((
  ref,
  videoId,
) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.getVideoDownloadUrl(videoId);

  final data = response['data'];

  if (data is Map && data['downloadUrl'] != null) {
    return data['downloadUrl'];
  }

  return '';
});
