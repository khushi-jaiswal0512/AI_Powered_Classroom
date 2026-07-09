import 'agora_engine_stub.dart'
    if (dart.library.html) 'agora_engine_web.dart'
    if (dart.library.io) 'agora_engine_mobile.dart';

typedef RemoteUserCallback = void Function(int uid);
typedef UserOfflineCallback = void Function();

abstract class AgoraEngine {
  factory AgoraEngine() => getAgoraEngine();

  Future<void> initialize(String appId);
  Future<void> joinChannel(String token, String channelId, String role);
  Future<void> leaveChannel();
  Future<void> muteLocalAudioStream(bool mute);
  Future<void> muteLocalVideoStream(bool mute);
  void dispose();
  
  // Callbacks for events
  set onRemoteUserJoined(RemoteUserCallback callback);
  set onRemoteUserOffline(UserOfflineCallback callback);
  
  // For UI to hook into
  Object? get localVideoView;
  Object? get remoteVideoView;
}