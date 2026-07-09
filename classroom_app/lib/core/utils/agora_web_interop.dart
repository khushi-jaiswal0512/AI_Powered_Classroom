@JS()
library agora_web_interop;

import 'package:js/js.dart';

@JS('AgoraRTC')
class AgoraRTC {
  external static IAgoraRTCClient createClient(ClientConfig config);
}

@JS()
@anonymous
class ClientConfig {
  external String get mode;
  external String get codec;

  external factory ClientConfig({String mode, String codec});
}

@JS()
class IAgoraRTCClient {
  external Future<dynamic> join(String appId, String channel, String token, [int? uid]);
  external Future<void> leave();
  external Future<void> publish(List<dynamic> tracks);
  external Future<void> unpublish(List<dynamic> tracks);
  external Future<dynamic> subscribe(dynamic user, String mediaType);
  
  external void on(String event, Function callback);
}

@JS('AgoraRTC.createMicrophoneAndCameraTracks')
external dynamic createMicrophoneAndCameraTracksRaw([dynamic audioConfig, dynamic videoConfig]);

@JS()
class ICameraVideoTrack {
  external void play(dynamic elementIdOrElement);
  external void stop();
  external void close();
}

@JS()
class IRemoteVideoTrack {
  external void play(dynamic elementIdOrElement);
  external void stop();
}
