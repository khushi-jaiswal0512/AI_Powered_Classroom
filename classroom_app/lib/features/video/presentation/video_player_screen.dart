import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:classroom_app/data/services/api_service.dart';
import 'package:classroom_app/core/constants/app_colors.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoId;
  final String? videoUrl;

  const VideoPlayerScreen({
    super.key,
    required this.videoId,
    this.videoUrl,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() =>
      _VideoPlayerScreenState();
}

class _VideoPlayerScreenState
    extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  bool _isLoading = true;
  String? _error;
  String _videoTitle = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      print("🚀 INIT PLAYER START");
      print("🆔 VIDEO ID: ${widget.videoId}");

      final api = ref.read(apiServiceProvider);

      String? playUrl = widget.videoUrl;
      print("📦 Initial URL: $playUrl");

      // ================= FETCH URL =================
      if (playUrl == null || playUrl.isEmpty) {
        final result = await api.getPlaybackUrl(widget.videoId);
        print("📡 API RESULT: $result");

        if (result['success'] == true) {
          final data = result['data'];

          if (data is! Map) {
            throw Exception("Invalid playback response");
          }

          playUrl =
              data['playbackUrl'] ??
              data['url'] ??
              data['videoUrl'] ??
              data['downloadUrl'];

          print("🎥 RAW URL: $playUrl");

          if (playUrl != null) {
            // 🔥 FULL CLEAN FIX
            playUrl = playUrl
                .replaceAll("\n", "")
                .replaceAll("\r", "")
                .replaceAll(" ", "")
                .replaceAll(".\n", ".")
                .replaceAll(".\r", ".")
                .replaceAll(". mp4", ".mp4")
                .replaceAll(".\nmp4", ".mp4")
                .replaceAll(".\rmp4", ".mp4")
                .trim();

            // extra normalization
            playUrl = Uri.parse(playUrl).toString();
          }

          print("🎯 FINAL FIXED URL: $playUrl");

          if (playUrl == null || playUrl.isEmpty) {
            throw Exception("Empty video URL");
          }

          _videoTitle = data['title'] ?? 'Lecture Video';
        } else {
          throw Exception(result['message']);
        }
      }

      // ================= INIT PLAYER =================
      print("⚙️ Initializing Controller...");

      final controller =
          VideoPlayerController.networkUrl(Uri.parse(playUrl!));

      await controller.initialize();
      await controller.setVolume(1.0);

      print("✅ Controller Ready");

      if (!mounted) return;

      _videoPlayerController = controller;

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: false, // ✅ no autoplay (browser safe)
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        aspectRatio:
            controller.value.aspectRatio == 0
                ? (16 / 9)
                : controller.value.aspectRatio,
        placeholder: const Center(
          child: CircularProgressIndicator(),
        ),
        errorBuilder: (context, message) {
          print("❌ PLAYER ERROR: $message");
          return Center(
            child: Text(
              "Playback Error: $message",
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          bufferedColor: Colors.grey,
          backgroundColor: Colors.white24,
        ),
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("🔥 ERROR: $e");

      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  // 🔥 manual play button (important for web)
  Widget _buildPlayButton() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          if (_videoPlayerController != null) {
            print("▶️ USER PLAY CLICK");

            _videoPlayerController!.play();
          }
        },
        child: const Center(
          child: Icon(
            Icons.play_circle_fill,
            size: 80,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_videoTitle),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(
                color: AppColors.primary,
              )
            : _error != null
                ? Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  )
                : (_videoPlayerController != null &&
                        _videoPlayerController!.value.isInitialized &&
                        _chewieController != null)
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio:
                                _videoPlayerController!.value.aspectRatio == 0
                                    ? 16 / 9
                                    : _videoPlayerController!
                                        .value.aspectRatio,
                            child: Chewie(
                              controller: _chewieController!,
                            ),
                          ),

                          // show play button when paused
                          if (!_videoPlayerController!.value.isPlaying)
                            _buildPlayButton(),
                        ],
                      )
                    : const Text(
                        "Video failed to load",
                        style: TextStyle(color: Colors.white),
                      ),
      ),
    );
  }
}