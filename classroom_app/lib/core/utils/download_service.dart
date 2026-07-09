import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  final Dio _dio = Dio();

  /// Downloads a video from an S3 presigned URL.
  /// On successful completion, returns the absolute path where the file was saved.
  /// Note: The progressCallback operates from 0.0 to 1.0.
  Future<String?> downloadS3Video({
    required String presignedUrl,
    required String title,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // 1. Determine local file save path (skips Web native file writing gracefully)
      if (kIsWeb) {
        throw UnsupportedError("Native file writing via Dio is unsupported on Web. Please trigger a browser download instead.");
      }

      // We typically use ApplicationDocumentsDirectory or DownloadsDirectory.
      // For cross-platform desktop/mobile support out-of-the-box:
      final directory = await getApplicationDocumentsDirectory();
      
      // Clean up the title to prevent path issues
      final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
      final savePath = '${directory.path}${Platform.pathSeparator}$safeTitle.mp4';

      // 2. Fire the Dio download request
      await _dio.download(
        presignedUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      // 3. Return target path
      return savePath;

    } catch (e) {
      debugPrint("Download Service Error: $e");
      return null;
    }
  }
}
