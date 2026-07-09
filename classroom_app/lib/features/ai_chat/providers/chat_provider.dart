import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/chat_message.dart';
import 'package:classroom_app/data/services/api_service.dart';

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

class ChatState {
  final List<ChatMessage> messages;
  final bool isTyping;

  ChatState({this.messages = const [], this.isTyping = false});

  ChatState copyWith({List<ChatMessage>? messages, bool? isTyping}) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  ApiService get _apiService => ref.read(apiServiceProvider);

  @override
  ChatState build() {
    return ChatState(messages: [
      ChatMessage(text: 'Hello! I am your AI Teaching Assistant. What doubt can I help you clear today?', isUser: false),
    ]);
  }

  Future<void> askDoubt(String question, String language) async {
    final userMsg = ChatMessage(text: question, isUser: true);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isTyping: true,
    );

    try {
      final response = await _apiService
          .askDoubt(question, language: language)
          .timeout(const Duration(seconds: 120));
      
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Server error');
      }

      final data = response['data'];
      final String rawReply = data is Map
          ? (data['response'] ?? data['answer'] ?? '').toString()
          : data?.toString() ?? '';
      if (rawReply.isEmpty) throw Exception("Empty response from AI");

      state = state.copyWith(isTyping: false);
      
      // Append an empty placeholder message for the AI
      state = state.copyWith(
        messages: [...state.messages, ChatMessage(text: '', isUser: false)],
      );

      // Chunk streaming simulation to avoid UI jank (5 chars per 20ms)
      const chunkSize = 5; 
      for (int i = 0; i < rawReply.length; i += chunkSize) {
        final end = (i + chunkSize < rawReply.length) ? i + chunkSize : rawReply.length;
        final currentText = rawReply.substring(0, end);
        
        await Future.delayed(const Duration(milliseconds: 20));
        
        final updatedMessages = List<ChatMessage>.from(state.messages);
        updatedMessages[updatedMessages.length - 1] = ChatMessage(
          text: currentText, 
          isUser: false
        );
        state = state.copyWith(messages: updatedMessages);
      }
    } catch (e) {
      final errorMsg = ChatMessage(
        text: 'AI is taking longer than expected. Please try again.', 
        isUser: false,
        isError: true
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isTyping: false,
      );
    }
  }
  
  void retryLastDoubt() {
    if (state.messages.isEmpty) return;
    final messages = List<ChatMessage>.from(state.messages);
    // remove the error message
    if (messages.last.isError) {
      messages.removeLast();
    }
    // find the last user message
    final lastUserMsg = messages.lastWhere((m) => m.isUser, orElse: () => ChatMessage(text: '', isUser: true));
    if (lastUserMsg.text.isNotEmpty) {
      state = state.copyWith(messages: messages);
      askDoubt(lastUserMsg.text, 'English');
    }
  }
}

