import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/live_class.dart';
import 'package:classroom_app/data/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

final liveClassesProvider = NotifierProvider<LiveClassesNotifier, AsyncValue<List<LiveClass>>>(
  LiveClassesNotifier.new,
);

class LiveClassesNotifier extends Notifier<AsyncValue<List<LiveClass>>> {
  ApiService get _apiService => ref.read(apiServiceProvider);

  @override
  AsyncValue<List<LiveClass>> build() {
    fetchClasses();
    return const AsyncValue.loading();
  }

  Future<void> fetchClasses({int? batchId}) async {
    state = const AsyncValue.loading();
    try {
      if (batchId == null) {
        state = const AsyncValue.data([]);
        return;
      }
      
      final response = await _apiService.getLiveClassStatus(batchId);
      if (response['statusCode'] == 204 || response['data'] == null) {
        state = const AsyncValue.data([]);
        return;
      }
      
      final dynamic e = response['data'];
      if (e is! Map) {
        state = const AsyncValue.data([]);
        return;
      }
      final liveClass = LiveClass(
        id: e['id'].toString(), 
        title: e['title'] ?? 'Untitled', 
        teacherName: e['teacherEmail'] ?? e['teacher'] ?? 'Unknown', 
        isLive: e['live'] ?? e['isLive'] ?? false,
        meetingId: e['meetingId'],
      );
      
      state = AsyncValue.data([liveClass]);
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 500 || e.response?.statusCode == 404) {
        state = const AsyncValue.data([]);
      } else {
        state = AsyncValue.error(e, st);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String?> createClass(String title, int batchId) async {
    // 🔧 FIX 4 (MOST IMPORTANT)
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      print("User not authenticated yet");
      return null;
    }

    // 🔧 FIX 3: API call se pehle confirm token
    final prefs = await SharedPreferences.getInstance();
    print("TOKEN BEFORE API: ${prefs.getString('token')}");

    try {
      final response = await _apiService.createLiveClass(title, batchId);
      final id = response['data']['id']?.toString();
      await fetchClasses(batchId: batchId); 
      return id;
    } on DioException catch (e) {
      debugPrint('❌ FAILED TO CREATE CLASS: ${e.response?.statusCode} - ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('❌ UNEXPECTED ERROR IN createClass: $e');
      return null;
    }
  }

  Future<bool> startClass(String classId) async {
    try {
      await _apiService.startLiveClass(classId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> endClass(String classId) async {
    try {
      await _apiService.endLiveClass(classId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> joinClass(String classId) async {
    try {
      final response = await _apiService.joinLiveClass(classId);
      return Map<String, dynamic>.from(response['data']);
    } catch (e) {
      return null;
    }
  }



  Future<bool> leaveClass(String classId) async {
    try {
      await _apiService.leaveLiveClass(classId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getClassToken(String classId) async {
    try {
      final response = await _apiService.getLiveClassToken(classId);
      return Map<String, dynamic>.from(response['data']);
    } catch (e) {
      return null;
    }
  }

  Future<int> getAttendance(String classId) async {
    try {
      final response = await _apiService.getAttendance(classId);
      return (response['data'] as num).toInt();
    } catch (e) {
      return 0;
    }
  }
}

