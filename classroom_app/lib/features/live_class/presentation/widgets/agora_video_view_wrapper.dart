import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'dart:ui' as ui;
import 'dart:html' as html;

// Use conditional import to handle platformViewRegistry in newer Flutter versions
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;

class AgoraVideoViewWrapper extends StatelessWidget {
  final dynamic engine; 
  final int? remoteUid;
  final bool isLocal;
  final String? webElementId;

  const AgoraVideoViewWrapper({
    super.key,
    required this.engine,
    this.remoteUid,
    this.isLocal = false,
    this.webElementId,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (webElementId == null) return const Center(child: Text("No Web Video"));
      
      ui_web.platformViewRegistry.registerViewFactory(
        webElementId!,
        (int viewId) {
          final div = html.DivElement()
            ..id = webElementId!
            ..style.width = '100%'
            ..style.height = '100%';
          return div;
        },
      );
      
      return HtmlElementView(viewType: webElementId!);
    } else {
      final rtcEngine = engine as RtcEngine;
      if (isLocal) {
        return AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: rtcEngine,
            canvas: const VideoCanvas(uid: 0),
          ),
        );
      } else {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: rtcEngine,
            canvas: VideoCanvas(uid: remoteUid),
            connection: const RtcConnection(channelId: ""), 
          ),
        );
      }
    }
  }
}
