import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:classroom_app/data/services/api_service.dart';

class AIDoubtState {
  final bool isLoading;
  final String? response;
  final String? error;

  AIDoubtState({this.isLoading = false, this.response, this.error});

  AIDoubtState copyWith({bool? isLoading, String? response, String? error}) {
    return AIDoubtState(
      isLoading: isLoading ?? this.isLoading,
      response: response ?? this.response,
      error: error ?? this.error,
    );
  }
}

final aiDoubtProvider = NotifierProvider<AIDoubtNotifier, AIDoubtState>(AIDoubtNotifier.new);

class AIDoubtNotifier extends Notifier<AIDoubtState> {
  ApiService get _apiService => ref.read(apiServiceProvider);

  @override
  AIDoubtState build() => AIDoubtState();

  Future<void> askDoubt(String question, {String language = 'English'}) async {
    state = state.copyWith(isLoading: true, error: null, response: null);
    final result = await _apiService.askDoubt(question, language: language);
    if (result['success'] == true) {
      // ✅ FIX: Safe response extraction
      final data = result['data'];
      final String? response = data is Map
          ? (data['response'] ?? data['answer'] ?? data.toString()).toString()
          : data?.toString();
      state = state.copyWith(isLoading: false, response: response);
    } else {
      state = state.copyWith(isLoading: false, error: result['message'] ?? 'Failed to get AI response');
    }
  }

  void clear() {
    state = AIDoubtState();
  }
}

