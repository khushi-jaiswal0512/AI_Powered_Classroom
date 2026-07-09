import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import '../providers/analytics_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsyncValue = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Analytics'),
        backgroundColor: Colors.transparent,
      ),
      body: analyticsAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (stats) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatCard(
                  context,
                  title: 'Overall Attendance',
                  value: '${(stats.attendancePercentage * 100).toStringAsFixed(1)}%',
                  icon: Icons.pie_chart,
                  color: AppColors.primary,
                ).animate().fadeIn().slideY(begin: -0.2),
                
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Total Students',
                        value: stats.totalStudents.toString(),
                        icon: Icons.people,
                        color: AppColors.secondary,
                      ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Present',
                        value: stats.attendanceCount.toString(),
                        icon: Icons.check_circle,
                        color: AppColors.success,
                      ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.2),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                
                Text(
                  'Attendance Goal Progress',
                  style: Theme.of(context).textTheme.titleLarge,
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 16),
                
                LinearProgressIndicator(
                  value: stats.attendancePercentage,
                  minHeight: 12,
                  backgroundColor: AppColors.surface,
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ).animate().fadeIn(delay: 400.ms).scaleX(alignment: Alignment.centerLeft),
                
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Target: 80%',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ).animate().fadeIn(delay: 500.ms),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

