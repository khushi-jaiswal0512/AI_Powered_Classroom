import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import 'student_dashboard_screen.dart';
import 'teacher_dashboard_screen.dart';
import 'package:classroom_app/core/constants/app_colors.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).role;
    final isTeacher = role == 'TEACHER';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTeacher ? 'Teacher Dashboard' : 'Student Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      // Delegate completely to isolated screens Based on Role map
      body: isTeacher ? const TeacherDashboardScreen() : const StudentDashboardScreen(),
      floatingActionButton: isTeacher ? null : FloatingActionButton(
        onPressed: () => context.push('/ai_chat'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.smart_toy, color: Colors.white),
      ),
    );
  }
}

