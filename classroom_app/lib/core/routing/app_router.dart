import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Authentication Screens
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';

// Dashboard & Analytics
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dashboard/presentation/hall_of_fame_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';

// Feature Screens
import '../../features/video/presentation/upload_screen.dart';
import '../../features/video/presentation/video_list_screen.dart';
import '../../features/video/presentation/video_player_screen.dart';
import '../../features/live_class/presentation/live_classes_screen.dart';
import '../../features/live_class/presentation/create_class_screen.dart';
import '../../features/live_class/presentation/live_stream_screen.dart';
import '../../features/ai_chat/presentation/chat_screen.dart';
import '../../features/quiz/presentation/quiz_screen.dart';
import '../../features/student/presentation/explore_courses_screen.dart';
import '../../features/dashboard/presentation/my_batches_screen.dart';
import '../../features/batch/presentation/batch_detail_screen.dart';

import 'package:classroom_app/features/auth/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true, // Enable this to see routing errors in terminal
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';
      final isAuthenticated = authState.isAuthenticated;

      // 1. If not logged in and not on public pages, force login
      if (!isAuthenticated && !isLoggingIn && !isRegistering) {
        return '/login';
      }

      // 2. If logged in and trying to access login/register, force dashboard
      if (isAuthenticated && (isLoggingIn || isRegistering)) {
        return '/dashboard';
      }

      // 3. IMPORTANT: Allow all other internal routes like /profile
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // --- PROFILE ROUTE (ENSURED AT ROOT) ---
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),

      // Video Routes
      GoRoute(
        path: '/video/upload',
        builder: (context, state) => const UploadScreen(),
      ),
      GoRoute(
        path: '/videos',
        builder: (context, state) => const VideoListScreen(),
      ),
      GoRoute(
        path: '/video/player/:id',
        builder: (context, state) {
          final videoId = state.pathParameters['id']!;
          return VideoPlayerScreen(videoId: videoId);
        },
      ),
      GoRoute(
        path: '/video-player',
        builder: (context, state) {
          final playableUrl = state.extra as String;
          return VideoPlayerScreen(videoId: '0', videoUrl: playableUrl);
        },
      ),

      // Live Class Routes
      GoRoute(
        path: '/live-classes',
        builder: (context, state) => const LiveClassesScreen(),
      ),
      GoRoute(
        path: '/live_class/create',
        builder: (context, state) => CreateClassScreen(),
      ),
      GoRoute(
        path: '/live_stream/:id',
        builder: (context, state) {
          final classId = state.pathParameters['id']!;
          return LiveStreamScreen(classId: classId);
        },
      ),

      // AI & Interaction
      GoRoute(
        path: '/ai_chat',
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: '/doubt-room',
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: '/quiz/:videoId',
        builder: (context, state) {
          final videoId = state.pathParameters['videoId'] ?? '1';
          return QuizScreen(videoId: videoId);
        },
      ),

      // Analytics & Hall of Fame
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/hall-of-fame',
        builder: (context, state) => const HallOfFameScreen(),
      ),

      // Batch & Student Exploration Routes
      GoRoute(
        path: '/explore',
        builder: (context, state) => const ExploreCoursesScreen(),
      ),
      GoRoute(
        path: '/my-batches',
        builder: (context, state) => const MyBatchesScreen(),
      ),
      GoRoute(
        path: '/batch/:id',
        builder: (context, state) {
          final batchIdStr = state.pathParameters['id']!;
          final batchId = int.tryParse(batchIdStr) ?? 0;
          return BatchDetailScreen(batchId: batchId);
        },
        routes: [
          GoRoute(
            path: 'videos',
            builder: (context, state) => BatchDetailScreen(
              batchId: int.parse(state.pathParameters['id']!),
              initialTab: 0,
            ),
          ),
          GoRoute(
            path: 'quizzes',
            builder: (context, state) => BatchDetailScreen(
              batchId: int.parse(state.pathParameters['id']!),
              initialTab: 1,
            ),
          ),
          GoRoute(
            path: 'live',
            builder: (context, state) => BatchDetailScreen(
              batchId: int.parse(state.pathParameters['id']!),
              initialTab: 2,
            ),
          ),
          GoRoute(
            path: 'chat',
            builder: (context, state) => BatchDetailScreen(
              batchId: int.parse(state.pathParameters['id']!),
              initialTab: 3,
            ),
          ),
        ],
      ),
    ],
  );
});

