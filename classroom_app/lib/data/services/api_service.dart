import 'dart:async';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:classroom_app/core/constants/api_constants.dart';
import 'package:classroom_app/features/auth/providers/auth_provider.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref);
});

/// ✅ STANDARD RESPONSE UNWRAPPER (BACKEND COMPATIBLE)
Map<String, dynamic> unwrapResponse(dynamic response) {
  if (response == null) {
    return {
      "success": false,
      "message": "No response from server",
      "data": null,
    };
  }

  if (response is Map) {
    // 1. Backend Standard Contract: {"success": bool, "data": ..., "message": ...}
    if (response.containsKey('success')) {
      final successValue = response['success'];
      // Handle bool, String "true", or int 1 as success
      final bool success = successValue == true || 
                           successValue == 'true' || 
                           successValue == 1;
      
      return {
        "success": success,
        "data": response['data'],
        "message": (response['message'] ?? response['error'] ?? "").toString(),
      };
    }

    // 2. Raw Map (e.g. video list wrapped in a non-standard field or a raw DTO)
    // We treat this as success=true for compatibility with video-showing.
    return {
      "success": true,
      "data": Map<String, dynamic>.from(response),
      "message": "",
    };
  }

  if (response is List) {
    // 3. Raw List (direct array from backend)
    return {
      "success": true,
      "data": response,
      "message": "",
    };
  }

  // 4. Fallback (AI natural text, empty strings, etc.)
  return {"success": true, "data": response, "message": ""};
}

class ApiService {
  final Dio _dio;
  final Ref _ref;

  ApiService(this._ref)
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: ApiConstants.coldStartTimeout,
          receiveTimeout: ApiConstants.coldStartTimeout,
          contentType: Headers.jsonContentType,
        ),
      ) {
    /// ✅ AUTH INTERCEPTOR
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },

        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();

            try {
              _ref.read(authProvider.notifier).logout();
            } catch (_) {}
          }

          return handler.next(e);
        },
      ),
    );

    /// ✅ LOGGING
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        logPrint: (obj) => dev.log(obj.toString(), name: 'Dio'),
      ),
    );
  }

  /// ✅ SAFE CALL WRAPPER
  Future<Map<String, dynamic>> _safeCall(
    Future<Response> Function() call,
  ) async {
    try {
      final response = await call();
      return unwrapResponse(response.data);
    } on DioException catch (e) {
      String message = 'Network error';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        message = 'Network slow';
      } else if (e.response != null) {
        final data = e.response?.data;
        final statusCode = e.response?.statusCode;

        if (statusCode == 403) {
          message = 'Upload permission error';
        } else if (statusCode == 500) {
          message = 'Server error';
        } else if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        } else {
          message = 'Error $statusCode';
        }
      }

      return {"success": false, "message": message};
    } catch (e) {
      return {"success": false, "message": "Unexpected error: $e"};
    }
  }

  // ================= AUTH =================

  Future<Map<String, dynamic>> login(String email, String password) async {
    return _safeCall(
      () => _dio
          .post(
            ApiConstants.login,
            data: {'email': email, 'password': password},
          )
          .timeout(ApiConstants.normalTimeout),
    );
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    return _safeCall(
      () => _dio
          .post(ApiConstants.register, data: data)
          .timeout(ApiConstants.coldStartTimeout),
    );
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    return _safeCall(
      () => _dio.get(ApiConstants.profile).timeout(ApiConstants.normalTimeout),
    );
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return _safeCall(
      () => _dio
          .put(ApiConstants.profile, data: data)
          .timeout(ApiConstants.normalTimeout),
    );
  }

  // ================= VIDEO =================

  Future<dynamic> getMyVideos() async {
  final res = await _safeCall(() => _dio.get(ApiConstants.myVideos));

  if (res['success'] == true) {
    final data = res['data'];

    if (data is List) return data;

    if (data is Map) {
      if (data['videos'] is List) return data['videos'];
      if (data['data'] is List) return data['data'];

      // fallback: find any list inside map
      final list = data.values.firstWhere(
        (v) => v is List,
        orElse: () => [],
      );

      if (list is List) return list;
    }
  }

  return [];
}

  Future<dynamic> getAllVideos() async {
  final res = await _safeCall(() => _dio.get(ApiConstants.allVideos));

  if (res['success'] == true) {
    final data = res['data'];

    if (data is List) return data;

    if (data is Map) {
      if (data['videos'] is List) return data['videos'];
      if (data['data'] is List) return data['data'];

      final list = data.values.firstWhere(
        (v) => v is List,
        orElse: () => [],
      );

      if (list is List) return list;
    }
  }

  return [];
}

  Future<Map<String, dynamic>> getVideoDownloadUrl(String videoId) async {
  final res = await _safeCall(
    // ✅ FIX: baseUrl already has /api/ — don't double-prefix
    () => _dio.get('${ApiConstants.downloadVideo}/$videoId'),
  );

  dev.log('📡 DOWNLOAD RAW RESPONSE: $res', name: 'Download');

  final data = res['data'];

  // Handle case where backend returns the URL as a plain string
  if (data is String && data.startsWith('http')) {
    return {"success": true, "data": {"downloadUrl": data}};
  }

  if (data is Map) {
    final url = data['downloadUrl'] ?? data['url'] ?? data['presignedUrl'] ?? '';
    if (url.toString().isNotEmpty) {
      return {"success": true, "data": {"downloadUrl": url.toString()}};
    }
  }

  return {
    "success": false,
    "message": "No download URL in response: $res",
    "data": {"downloadUrl": ""},
  };
}

  Future<Map<String, dynamic>> getPlaybackUrl(String videoId) async {
  print("🎯 CALLING PLAYBACK API FOR ID: $videoId");

  final res = await _safeCall(
    () => _dio.get('${ApiConstants.playbackVideo}/$videoId'),
  );

  print("📡 RAW RESPONSE: $res");

  // ❌ if API failed
  if (res['success'] != true) {
    print("❌ API FAILED: ${res['message']}");
    return {
      "success": false,
      "data": {
        "url": "",
        "title": "Lecture Video",
      },
      "message": res['message'] ?? "API failed",
    };
  }

  final data = res['data'];

  print("📦 PARSED DATA: $data");

  if (data is! Map) {
    print("❌ INVALID DATA FORMAT");
    return {
      "success": false,
      "data": {
        "url": "",
        "title": "Lecture Video",
      },
    };
  }

  final url =
      data['url'] ??
      data['videoUrl'] ??
      data['downloadUrl'] ??
      "";

  print("🎥 FINAL URL: $url");

  if (url.isEmpty) {
    print("❌ EMPTY VIDEO URL");
    return {
      "success": false,
      "data": {
        "url": "",
        "title": "Lecture Video",
      },
    };
  }

  return {
    "success": true,
    "data": {
      "url": url,
      "title": data['title'] ?? "Lecture Video",
    },
  };
}

  Future<dynamic> getVideosByBatch(int batchId) async {
    final res = await _safeCall(
      () => _dio.get('${ApiConstants.batchVideos}/$batchId'),
    );

    if (res['success'] == true) {
      final data = res['data'];
      if (data is List) return data;
      if (data is Map && data['videos'] is List) return data['videos'];
      if (data is Map && data['data'] is List) return data['data'];
    }

    return [];
  }

  Future<Map<String, dynamic>> getUploadUrl(String filename) async {
  final res = await _safeCall(
    () => _dio.get(
      ApiConstants.uploadUrl,
      queryParameters: {'fileName': filename},
    ),
  );

  final data = res['data'];

  // ✅ Case 1: Proper wrapped response
  if (data is Map && data.containsKey('uploadUrl')) {
    return res;
  }

  // ✅ Case 2: Backend returned raw object (unwrapResponse already put it in data)
  if (data is Map &&
      data.containsKey('uploadUrl') &&
      data.containsKey('fileUrl')) {
    return {
      "success": true,
      "data": data,
    };
  }

  // ✅ Fail-safe (do NOT crash app)
  return {
    "success": false,
    "message": "Invalid upload URL response",
    "data": null,
  };
}

  Future<Map<String, dynamic>> saveVideoMetadata(
    String title,
    String fileUrl,
    int batchId,
    String transcript,
  ) async {
    return _safeCall(
      () => _dio.post(
        ApiConstants.saveVideo,
        data: FormData.fromMap({
          'title': title,
          'url': fileUrl,
          'batchId': batchId,
          'transcript': transcript,
        }),
      ),
    );
  }

  /// ✅ S3 UPLOAD (FIXED 403 ISSUE)
  Future<Response> uploadToS3(String url, List<int> bytes) async {
  final dio = Dio();
  int retryCount = 0;

  while (true) {
    try {
      return await dio
          .put(
            url,
            data: Stream.fromIterable([bytes]),
            options: Options(
              headers: {
                Headers.contentLengthHeader: bytes.length,
                "Content-Type": "application/octet-stream", // ✅ FIXED
              },
              followRedirects: false,
              validateStatus: (status) => status != null && status < 500,
            ),
          )
          .timeout(const Duration(minutes: 10));
    } catch (e) {
      if (retryCount < 1) {
        retryCount++;
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }
      throw Exception("Upload failed: $e");
    }
  }
}

  // ================= QUIZ =================

  Future<Map<String, dynamic>> getQuizForVideo(String videoId) async {
    return _safeCall(() => _dio.get('${ApiConstants.quizForVideo}/$videoId'));
  }

  Future<Map<String, dynamic>> generateQuiz(int videoId) async {
    return _safeCall(
      () => _dio.post(
        ApiConstants.generateQuiz,
        data: {'videoId': videoId},
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> submitQuizAnswers(
    int quizId,
    Map<String, String> answers,
  ) async {
    return _safeCall(
      () => _dio.post(
        ApiConstants.submitQuiz,
        // ✅ FIX: backend QuizAttemptRequest expects 'answers', NOT 'studentAnswers'
        data: {'quizId': quizId, 'answers': answers},
      ),
    );
  }

  // ================= AI =================

  Future<Map<String, dynamic>> askDoubt(
    String question, {
    String language = 'English',
  }) async {
    final res = await _safeCall(
      () => _dio.post(
        ApiConstants.doubt,
        data: {'question': question, 'language': language},
      ),
    );

    // 🔥 HANDLE STRING RESPONSE (VERY IMPORTANT)
    if (res['data'] is String) {
      return {
        "success": true,
        "data": {"response": res['data']},
      };
    }

    final data = res['data'];
    if (data is Map) {
      final answer = data['answer'] ?? data['response'] ?? data['message'];
      if (answer != null && answer.toString().trim().isNotEmpty) {
        return {
          "success": res['success'] == true,
          "data": {"response": answer.toString()},
          "message": res['message'] ?? "",
        };
      }
    }

    return res;
  }

  // ================= RECOMMENDATION =================

  /// GET /api/recommendation
  /// Returns [{type, focus}, ...] — RecommendationResponse list
  Future<Map<String, dynamic>> getRecommendations() async {
    return _safeCall(() => _dio.get(ApiConstants.recommendations));
  }

  /// GET /api/recommendation/trend
  /// Returns [{date, score}, ...] — ProgressTrendResponse list
  Future<Map<String, dynamic>> getProgressTrend() async {
    return _safeCall(() => _dio.get(ApiConstants.recommendationTrend));
  }

  // ================= BATCH =================


  Future<Map<String, dynamic>> getMyBatches() async {
    return _safeCall(() => _dio.get(ApiConstants.myBatches));
  }

  Future<Map<String, dynamic>> joinBatch(String code) async {
    return _safeCall(
      () =>
          _dio.post(ApiConstants.joinBatch, data: {'code': code.toUpperCase()}),
    );
  }


  // ================= BATCH (Restored) =================
  Future<Map<String, dynamic>> getAllBatches() async {
    return _safeCall(() => _dio.get('batch/all'));
  }

  Future<Map<String, dynamic>> createBatch(String name, String subject) async {
    return _safeCall(
      () => _dio.post(
        ApiConstants.createBatch,
        data: {'name': name, 'subject': subject},
      ),
    );
  }

  // ================= QUIZ (Restored) =================
  Future<bool> checkQuizExists(int videoId) async {
  try {
    final res = await _safeCall(
      () => _dio.get('${ApiConstants.quizForVideo}/$videoId'),
    );

    return res['success'] == true &&
        res['data'] != null &&
        res['data'] is Map &&
        res['data']['questions'] is List &&
        (res['data']['questions'] as List).isNotEmpty;
  } catch (_) {
    return false;
  }
}

  Future<Map<String, dynamic>> generateAdaptiveQuiz(int videoId) async {
    return _safeCall(
      () => _dio.post(
        '${ApiConstants.adaptiveQuiz}/$videoId',
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
      ),
    );
  }

  // ================= DASHBOARD (Restored) =================
  Future<Map<String, dynamic>> getStudentDashboard() async {
    return _safeCall(() => _dio.get(ApiConstants.studentDashboard));
  }

  Future<Map<String, dynamic>> getTeacherDashboard() async {
    return _safeCall(() => _dio.get(ApiConstants.teacherDashboard));
  }

  // ================= LIVE CLASS (Restored) =================
  Future<Map<String, dynamic>> getLiveClassStatus(int batchId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.classStatus}/$batchId',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );

      if (response.statusCode == 204 || response.data == null) {
        return {"success": true, "data": null, "statusCode": response.statusCode};
      }

      return unwrapResponse(response.data);
    } on DioException catch (e) {
      return {
        "success": false,
        "message": e.response?.data?.toString() ?? e.message ?? "Live status failed",
        "data": null,
      };
    }
  }

  Future<Map<String, dynamic>> createLiveClass(
    String title,
    int batchId,
  ) async {
    return _safeCall(
      () => _dio.post(
        ApiConstants.createClass,
        data: {'title': title, 'batchId': batchId},
      ),
    );
  }

  Future<Map<String, dynamic>> startLiveClass(String classId) async {
    return _safeCall(
      () => _dio.post(
        ApiConstants.startClass,
        data: {'classId': int.parse(classId)},
      ),
    );
  }

  Future<Map<String, dynamic>> endLiveClass(String classId) async {
    return _safeCall(
      () => _dio.post(
        ApiConstants.endClass,
        data: {'classId': int.parse(classId)},
      ),
    );
  }

  Future<Map<String, dynamic>> joinLiveClass(String classId) async {
    return _safeCall(() => _dio.post('${ApiConstants.joinClass}/$classId'));
  }

  Future<Map<String, dynamic>> leaveLiveClass(String classId) async {
    return _safeCall(() => _dio.post('${ApiConstants.leaveClass}/$classId'));
  }

  Future<Map<String, dynamic>> getLiveClassToken(String classId) async {
    return _safeCall(() => _dio.get('${ApiConstants.classToken}/$classId'));
  }

  Future<Map<String, dynamic>> getAttendance(String classId) async {
    return _safeCall(() => _dio.get('${ApiConstants.attendance}/$classId'));
  }

  // ================= AI / TRANSCRIPT (Restored) =================
  Future<Map<String, dynamic>> generateTranscript(
    String videoId, {
    bool force = false,
  }) async {
    return _safeCall(
      () => _dio.post(
        '${ApiConstants.transcribe}/$videoId',
        queryParameters: {'force': force},
      ),
    );
  }
}
