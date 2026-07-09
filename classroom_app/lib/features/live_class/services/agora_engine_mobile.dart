import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'agora_engine.dart';

AgoraEngine getAgoraEngine() => AgoraEngineMobile();

class AgoraEngineMobile implements AgoraEngine {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _isInitialized = false;
  
  RemoteUserCallback? _onRemoteUserJoined;
  UserOfflineCallback? _onRemoteUserOffline;

  @override
  set onRemoteUserJoined(RemoteUserCallback callback) => _onRemoteUserJoined = callback;
  
  @override
  set onRemoteUserOffline(UserOfflineCallback callback) => _onRemoteUserOffline = callback;

  @override
  Future<void> initialize(String appId) async {
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Local user ${connection.localUid} joined");
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Remote user $remoteUid joined");
          _remoteUid = remoteUid;
          _onRemoteUserJoined?.call(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("Remote user $remoteUid left");
          _remoteUid = null;
          _onRemoteUserOffline?.call();
        },
      ),
    );

    _isInitialized = true;
  }

  @override
  Future<void> joinChannel(String token, String channelId, String role) async {
    if (!_isInitialized) return;
    
    await _engine!.setClientRole(
      role: role == 'PUBLISHER' 
          ? ClientRoleType.clientRoleBroadcaster 
          : ClientRoleType.clientRoleAudience
    );
    
    await _engine!.enableVideo();
    await _engine!.startPreview();

    await _engine!.joinChannel(
      token: token,
      channelId: channelId,
      uid: 0,
      options: const ChannelMediaOptions(),
    );

    // Ensure teacher starts publishing immediately
    if (role == 'PUBLISHER') {
      await _engine!.muteLocalAudioStream(false);
      await _engine!.muteLocalVideoStream(false);
    }
  }

  @override
  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
  }

  @override
  Future<void> muteLocalAudioStream(bool mute) async {
    await _engine?.muteLocalAudioStream(mute);
  }

  @override
  Future<void> muteLocalVideoStream(bool mute) async {
    await _engine?.muteLocalVideoStream(mute);
  }

  @override
  void dispose() {
    _engine?.release();
  }

  @override
  Object? get localVideoView => _engine;

  @override
  Object? get remoteVideoView => _remoteUid;
}
