import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import '../services/agora_engine.dart';
import './widgets/agora_video_view_wrapper.dart';
import '../providers/live_class_provider.dart';
import '../../auth/providers/auth_provider.dart';

class LiveStreamScreen extends ConsumerStatefulWidget {
  final String classId;

  const LiveStreamScreen({super.key, required this.classId});

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen> {
  late AgoraEngine _agoraEngine;

  int? _remoteUid;
  bool _localUserJoined = false;

  bool isMicMuted = false;
  bool isCameraOff = false;

  bool _isLoading = true;
  String? _error;

  String? _token;
  String? _meetingId;
  String? _role;
  DateTime? _connectedAt;

  @override
  void initState() {
    super.initState();
    _agoraEngine = AgoraEngine();
    _connectToClass();
  }

  @override
  void dispose() {
    _agoraEngine.dispose();
    super.dispose();
  }

  // ========================= CONNECT =========================

  Future<void> _connectToClass() async {
    try {
      final isTeacher = ref.read(authProvider).role == 'TEACHER';
      final liveProvider = ref.read(liveClassesProvider.notifier);

      if (!isTeacher) {
        final joinRes = await liveProvider.joinClass(widget.classId);
        if (joinRes == null) throw Exception("Join failed");
      }

      final tokenRes = await liveProvider.getClassToken(widget.classId);
      if (tokenRes == null) throw Exception("Token failed");

      _token = tokenRes['token'];
      _meetingId = tokenRes['meetingId'] ?? tokenRes['channel'];
      _role = isTeacher ? 'PUBLISHER' : 'SUBSCRIBER';

      // 🔥 CRITICAL FIX (race condition)
      await Future.delayed(const Duration(milliseconds: 500));

      await _initAgora(tokenRes['appId']);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ========================= INIT =========================

  Future<void> _initAgora(String appId) async {
    if (!kIsWeb) {
      await [Permission.microphone, Permission.camera].request();
    }

    await _agoraEngine.initialize(appId);

    _agoraEngine.onRemoteUserJoined = (uid) {
      setState(() => _remoteUid = uid);
    };

    _agoraEngine.onRemoteUserOffline = () {
      setState(() => _remoteUid = null);
    };

    await _agoraEngine.joinChannel(_token!, _meetingId!, _role!);

    final isTeacher = ref.read(authProvider).role == 'TEACHER';

    // 🔥 STUDENT FIX (no camera)
    if (!isTeacher) {
      await _agoraEngine.muteLocalVideoStream(true);
      await _agoraEngine.muteLocalAudioStream(false);
    }

    setState(() {
      _localUserJoined = true;
      _isLoading = false;
      _connectedAt = DateTime.now();
    });
  }

  // ========================= UI =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _mainVideo()),

          if (_localUserJoined && !_isTeacher() && _remoteUid != null)
            Positioned(
              top: 96,
              right: 16,
              child: _localPreview(),
            ),

          if (_isLoading) _loadingUI(),
          if (_error != null) _errorUI(),

          _topBar(),
          _controls(),
        ],
      ),
    );
  }

  // ========================= VIDEO LOGIC =========================

  bool _isTeacher() => ref.read(authProvider).role == 'TEACHER';

  Widget _mainVideo() {
    if (_isTeacher()) {
      if (!_localUserJoined) {
        return _placeholder("Starting camera...");
      }

      return AgoraVideoViewWrapper(
        engine: _agoraEngine.localVideoView,
        isLocal: true,
        webElementId: kIsWeb ? 'local-video' : null,
      );
    }

    if (_remoteUid != null) {
      return AgoraVideoViewWrapper(
        engine: _agoraEngine.remoteVideoView,
        remoteUid: _remoteUid,
        webElementId: kIsWeb ? 'remote-video' : null,
      );
    }

    return _placeholder("Waiting for teacher...");
  }

  Widget _localPreview() {
    return Container(
      width: 132,
      height: 176,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF111827),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AgoraVideoViewWrapper(
            engine: _agoraEngine.localVideoView,
            isLocal: true,
            webElementId: kIsWeb ? 'local-preview-video' : null,
          ),
          const Positioned(
            left: 10,
            bottom: 8,
            child: Text(
              'You',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ========================= CONTROLS =========================

  Widget _controls() {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: SafeArea(
        top: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xE61A1D29),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _controlButton(
                  icon: isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: isMicMuted ? 'Muted' : 'Mic',
                  active: !isMicMuted,
                  onTap: _toggleMic,
                ),
                const SizedBox(width: 12),
                _endButton(),
                const SizedBox(width: 12),
                _controlButton(
                  icon: isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                  label: isCameraOff ? 'Camera off' : 'Camera',
                  active: !isCameraOff,
                  onTap: _toggleCamera,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = active ? Colors.white : Colors.redAccent;
    return Material(
      color: active ? Colors.white.withOpacity(0.12) : Colors.redAccent.withOpacity(0.16),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 88,
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _endButton() {
    return Material(
      color: Colors.redAccent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: _leaveClass,
        borderRadius: BorderRadius.circular(22),
        child: const SizedBox(
          width: 74,
          height: 58,
          child: Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  // ========================= ACTIONS =========================

  void _toggleMic() async {
    final newState = !isMicMuted;
    await _agoraEngine.muteLocalAudioStream(newState);
    setState(() => isMicMuted = newState);
  }

  void _toggleCamera() async {
    final newState = !isCameraOff;
    await _agoraEngine.muteLocalVideoStream(newState);
    setState(() => isCameraOff = newState);
  }

  Future<void> _leaveClass() async {
    await _agoraEngine.leaveChannel();
    if (_isTeacher()) {
      await ref.read(liveClassesProvider.notifier).endClass(widget.classId);
    } else {
      await ref.read(liveClassesProvider.notifier).leaveClass(widget.classId);
    }
    if (mounted) context.pop();
  }

  // ========================= UI HELPERS =========================

  Widget _loadingUI() {
    return Container(
      color: const Color(0xFF080A12),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 18),
            Text(
              'Joining live classroom...',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorUI() {
    return Container(
      color: const Color(0xFF080A12),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 42),
              const SizedBox(height: 14),
              const Text(
                'Could not join live class',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(String text) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF080A12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.video_call_rounded, color: Colors.white70, size: 44),
            ),
            const SizedBox(height: 18),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your session will appear here automatically.',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xB30D111C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: _leaveClass,
                  tooltip: 'Leave',
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isTeacher() ? 'Teaching live' : 'Live classroom',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _meetingId ?? 'Connecting...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _statusPill(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusPill() {
    final minutes = _connectedAt == null
        ? 0
        : DateTime.now().difference(_connectedAt!).inMinutes;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.35)),
      ),
      child: Text(
        minutes == 0 ? 'LIVE' : '${minutes}m LIVE',
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
