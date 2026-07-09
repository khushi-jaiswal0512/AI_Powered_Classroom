import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
// Use JS utility from package:js for better compatibility if dart:js_util is problematic in some analyzer contexts
import 'package:js/js_util.dart' as js_util;
import 'package:js/js.dart';
import '../../../core/utils/agora_web_interop.dart';
import 'agora_engine.dart';

AgoraEngine getAgoraEngine() => AgoraEngineWeb();

class AgoraEngineWeb implements AgoraEngine {
  IAgoraRTCClient? _client;
  List<dynamic> _localTracks = [];
  String? _appId;
  bool _isInitialized = false;
  
  RemoteUserCallback? _onRemoteUserJoined;
  UserOfflineCallback? _onRemoteUserOffline;

  @override
  set onRemoteUserJoined(RemoteUserCallback callback) => _onRemoteUserJoined = callback;
  
  @override
  set onRemoteUserOffline(UserOfflineCallback callback) => _onRemoteUserOffline = callback;

  @override
  Future<void> initialize(String appId) async {
    _appId = appId;
    _client = AgoraRTC.createClient(ClientConfig(mode: 'live', codec: 'vp8'));
    _isInitialized = true;
  }

  @override
  Future<void> joinChannel(String token, String channelId, String role) async {
    if (!_isInitialized) return;

    _client!.on('user-published', js.allowInterop((user, mediaType) async {
      await _client!.subscribe(user, mediaType);
      if (mediaType == 'video') {
        user.videoTrack.play('remote-video');
        _onRemoteUserJoined?.call(user.uid);
      }
      if (mediaType == 'audio') {
        user.audioTrack.play();
      }
    }));

    _client!.on('user-unpublished', allowInterop((user, mediaType) {
      if (mediaType == 'video') {
        _onRemoteUserOffline?.call();
      }
    }));

    if (role == 'PUBLISHER') {
      await js_util.promiseToFuture(
        js_util.callMethod(_client!, 'setClientRole', ['host'])
      );
    } else {
      await js_util.promiseToFuture(
        js_util.callMethod(_client!, 'setClientRole', ['audience'])
      );
    }

    await js_util.promiseToFuture(
      js_util.callMethod(_client!, 'join', [_appId, channelId, token, null])
    );
    print("✅ JOIN SUCCESS: $channelId");

    if (role == 'PUBLISHER') {
      try {
        print("🔍 Creating local tracks (Safe js_util flow)...");
        
        // 1. call raw JS function (returns Promise)
        final promise = createMicrophoneAndCameraTracksRaw();

        // 2. convert Promise → Dart Future
        final tracks = await js_util.promiseToFuture(promise);

        if (tracks == null) {
          throw Exception("❌ Tracks NULL (permission issue or SDK delay)");
        }

        // 3. extract safely using js_util
        final audioTrack = js_util.getProperty(tracks, 0);
        final videoTrack = js_util.getProperty(tracks, 1);

        if (audioTrack == null || videoTrack == null) {
          throw Exception("❌ Tracks not created properly (null extraction)");
        }

        _localTracks = [audioTrack, videoTrack];

        // 4. Wait for DOM to render (HtmlElementView delay)
        await Future.delayed(const Duration(milliseconds: 300));

        // 5. Play preview
        js_util.callMethod(videoTrack, 'play', ['local-video']);
        
        // 6. Safe publish with jsify
        await js_util.promiseToFuture(
          js_util.callMethod(_client!, 'publish', [js_util.jsify(_localTracks)])
        );
        
        print("✅ PUBLISH SUCCESS");
      } catch (e) {
        print("❌ AGORA PUBLISH ERROR: $e");
        rethrow;
      }
    }
  }

  @override
  Future<void> muteLocalAudioStream(bool mute) async {
    if (_localTracks.isNotEmpty) {
      final audioTrack = _localTracks[0];
      if (audioTrack != null) {
        js_util.callMethod(audioTrack, 'setEnabled', [!mute]);
      }
    }
  }

  @override
  Future<void> muteLocalVideoStream(bool mute) async {
    if (_localTracks.isNotEmpty) {
      final videoTrack = _localTracks[1];
      if (videoTrack != null) {
        js_util.callMethod(videoTrack, 'setEnabled', [!mute]);
      }
    }
  }

  @override
  Future<void> leaveChannel() async {
    for (var track in _localTracks) {
      track.stop();
      track.close();
    }
    await _client?.leave();
  }

  @override
  void dispose() {
    leaveChannel();
  }

  @override
  Object? get localVideoView => 'local-video';

  @override
  Object? get remoteVideoView => 'remote-video';
}
