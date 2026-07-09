// FULL FILE — SAFE + PRODUCTION READY

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:classroom_app/data/services/api_service.dart';
import 'package:classroom_app/features/video/providers/video_library_provider.dart';

final uploadProvider = NotifierProvider<UploadNotifier, UploadState>(UploadNotifier.new);

class UploadState {
  final bool isUploading;
  final String? error;
  final bool isSuccess;
  final String? progress;
  final String? tempFileUrl;
  final bool isS3Uploaded;
  final int? selectedBatchId;

  UploadState({
    this.isUploading = false,
    this.error,
    this.isSuccess = false,
    this.progress,
    this.tempFileUrl,
    this.isS3Uploaded = false,
    this.selectedBatchId,
  });

  UploadState copyWith({
    bool? isUploading,
    String? error,
    bool? isSuccess,
    String? progress,
    String? tempFileUrl,
    bool? isS3Uploaded,
    int? selectedBatchId,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      error: error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
      progress: progress ?? this.progress,
      tempFileUrl: tempFileUrl ?? this.tempFileUrl,
      isS3Uploaded: isS3Uploaded ?? this.isS3Uploaded,
      selectedBatchId: selectedBatchId ?? this.selectedBatchId,
    );
  }
}

class UploadNotifier extends Notifier<UploadState> {
  ApiService get _apiService => ref.read(apiServiceProvider);

  @override
  UploadState build() => UploadState();

  void setBatch(int batchId) {
    state = state.copyWith(selectedBatchId: batchId);
  }

  /// 🔥 FIXED S3 FLOW
  Future<bool> performS3Upload(Uint8List bytes, String fileName) async {
    state = state.copyWith(
      isUploading: true,
      error: null,
      progress: 'Requesting upload URL...',
    );

    try {
      final urlResult = await _apiService.getUploadUrl(fileName);

      if (urlResult['success'] != true) {
        throw Exception(urlResult['message'] ?? "Failed to get upload URL");
      }

      final raw = urlResult['data'];

      if (raw is! Map) {
        throw Exception("Invalid upload response format");
      }

      final uploadUrl = raw['uploadUrl'];
      final fileUrl = raw['fileUrl'];

      if (uploadUrl == null || fileUrl == null) {
        throw Exception("uploadUrl or fileUrl missing");
      }

      state = state.copyWith(progress: 'Uploading to storage...');

      await _apiService.uploadToS3(uploadUrl.toString(), bytes);

      state = state.copyWith(
        isUploading: false,
        isS3Uploaded: true,
        tempFileUrl: fileUrl.toString(),
        progress: 'Upload complete! Click Save',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// 🔥 FIXED SAVE + AUTO TRANSCRIPT
  Future<bool> finalizeMetadata(String title, {String? transcript, int attempt = 0}) async {
    if (state.tempFileUrl == null || state.selectedBatchId == null) {
      state = state.copyWith(error: "Missing upload data");
      return false;
    }

    state = state.copyWith(isUploading: true, error: null, progress: 'Saving metadata...');

    try {
      final result = await _apiService.saveVideoMetadata(
        title,
        state.tempFileUrl!,
        state.selectedBatchId!,
        transcript ?? "",
      );

      if (result['success'] == true) {

        // 🔥 NEW FIX: AUTO TRANSCRIPT TRIGGER
        final videoId = result['data']?['id']?.toString();
        if (videoId != null) {
          try {
            await _apiService.generateTranscript(videoId);
          } catch (_) {
            // silently ignore (non-blocking)
          }
        }

        state = state.copyWith(
          isUploading: false,
          isSuccess: true,
          progress: 'Saved successfully!',
        );

        ref.invalidate(videoLibraryProvider);
        return true;
      } else {
        throw Exception(result['message'] ?? 'Failed to save metadata');
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('Slow network') && attempt == 0) {
        return finalizeMetadata(title, transcript: transcript, attempt: 1);
      }
      state = state.copyWith(isUploading: false, error: msg);
      return false;
    }
  }

  void reset() => state = UploadState();

  Future<bool> uploadVideo(
    String title,
    Uint8List bytes,
    String fileName, {
    String? transcript,
  }) async {
    if (state.selectedBatchId == null) {
      state = state.copyWith(error: "Please select a batch");
      return false;
    }

    final s3Success = await performS3Upload(bytes, fileName);
    if (!s3Success) return false;

    return await finalizeMetadata(title, transcript: transcript);
  }
}