import 'dart:async';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:classroom_app/data/services/api_service.dart';

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

String _normalizeRole(String raw) =>
    raw.toUpperCase().replaceFirst('ROLE_', '');

class AuthState {
  final bool isLoading;
  final bool isColdStart;
  final String? error;
  final bool isAuthenticated;
  final String role;
  final String name;
  final String email;
  final String phone;

  AuthState({
    this.isLoading = false,
    this.isColdStart = false,
    this.error,
    this.isAuthenticated = false,
    this.role = 'STUDENT',
    this.name = '',
    this.email = '',
    this.phone = '',
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isColdStart,
    String? error,
    bool? isAuthenticated,
    String? role,
    String? name,
    String? email,
    String? phone,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isColdStart: isColdStart ?? this.isColdStart,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  ApiService get _apiService => ref.read(apiServiceProvider);

  @override
  AuthState build() {
    Future.microtask(_checkInitialAuth);
    return AuthState();
  }

  Future<void> _checkInitialAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) return;

    try {
      final profileRes = await _apiService.getUserProfile();
      final res = unwrapResponse(profileRes);

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];

        state = state.copyWith(
          isAuthenticated: true,
          role: _normalizeRole(data['role'] ?? 'STUDENT'),
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          phone: data['phone'] ?? '',
        );
      } else {
        await logout();
      }
    } catch (_) {
      await logout();
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final res = await _apiService.login(email, password);

      if (res['success'] != true) {
        throw Exception(res['message']);
      }

      final token = res['data']?['token'];
      if (token == null) throw Exception("Token missing");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      // fetch profile
      final profile = await _apiService.getUserProfile();

      if (profile['success'] == true) {
        final data = profile['data'];

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          role: _normalizeRole(data['role'] ?? 'STUDENT'),
          name: data['name'] ?? '',
          email: data['email'] ?? email,
          phone: data['phone'] ?? '',
        );
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = AuthState();
  }

  Future<bool> updateProfile(String name, String email, String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.updateProfile({
        'name': name,
        'email': email,
        'phone': phone,
      });

      if (response['success'] == true) {
        state = state.copyWith(
          isLoading: false,
          name: name,
          email: email,
          phone: phone,
        );
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: response['message']);
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to update profile: $e');
      return false;
    }
  }

  // --- REGISTRATION LOGIC ---
  Future<bool> registerWithRetry(
    String name,
    String email,
    String password,
    String role, {
    int maxRetries = 2,
  }) async {
    state = state.copyWith(isLoading: true, isColdStart: false, error: null);

    final payload = {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    };

    for (int attempt = 1; attempt <= maxRetries + 1; attempt++) {
      try {
        final res = await _apiService.register(payload);
        if (res['success'] == true) {
          state = state.copyWith(isLoading: false, isColdStart: false);
          return true;
        } else {
          throw Exception(res['message'] ?? 'Registration failed');
        }
      } catch (e) {
        final msg = e.toString().replaceAll('Exception: ', '');
        if (msg.contains('timeout') || msg.contains('waking up')) {
          if (attempt <= maxRetries) {
            state = state.copyWith(isLoading: true, isColdStart: true);
            await Future.delayed(const Duration(seconds: 5));
            continue;
          }
        }
        state = state.copyWith(
          isLoading: false,
          isColdStart: false,
          error: msg,
        );
        return false;
      }
    }
    return false;
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    String role,
  ) => registerWithRetry(name, email, password, role, maxRetries: 2);
}