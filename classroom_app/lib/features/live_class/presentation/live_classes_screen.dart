import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/live_class_provider.dart';

class LiveClassesScreen extends ConsumerWidget {
  const LiveClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesState = ref.watch(liveClassesProvider);
    final isTeacher = ref.watch(authProvider).role.toUpperCase() == 'TEACHER';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Live Classes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(liveClassesProvider.notifier).fetchClasses(),
          ),
        ],
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/live_class/create'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add),
              label: const Text('New Class'),
            ).animate().fadeIn().scale()
          : null,
      body: classesState.when(
        loading: () => _buildSkeletonLoader(),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              Text(
                'Could not load classes.\nCheck your connection.',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.read(liveClassesProvider.notifier).fetchClasses(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.live_tv_rounded, size: 72, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text('No live classes right now', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
                ],
              ),
            );
          }
          
          final liveClasses = classes.where((c) => c.isLive).toList();
          final scheduledClasses = classes.where((c) => !c.isLive).toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(liveClassesProvider.notifier).fetchClasses(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (liveClasses.isNotEmpty) ...[
                  _SectionHeader(title: '🔴 Live Now', count: liveClasses.length),
                  const SizedBox(height: 12),
                  ...liveClasses.asMap().entries.map((e) =>
                    _LiveClassCard(
                      cls: e.value,
                      isTeacher: isTeacher,
                      index: e.key,
                    )
                  ),
                  const SizedBox(height: 24),
                ],
                if (scheduledClasses.isNotEmpty) ...[
                  _SectionHeader(title: '📅 Scheduled', count: scheduledClasses.length),
                  const SizedBox(height: 12),
                  ...scheduledClasses.asMap().entries.map((e) =>
                    _LiveClassCard(
                      cls: e.value,
                      isTeacher: isTeacher,
                      index: e.key + liveClasses.length,
                    )
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white10),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
          child: Text('$count', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ],
    );
  }
}

class _LiveClassCard extends ConsumerWidget {
  final dynamic cls;
  final bool isTeacher;
  final int index;

  const _LiveClassCard({required this.cls, required this.isTeacher, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLive = cls.isLive as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? Colors.red.withOpacity(0.5) : Colors.white.withOpacity(0.08),
          width: isLive ? 1.5 : 1,
        ),
        boxShadow: isLive
            ? [BoxShadow(color: Colors.red.withOpacity(0.15), blurRadius: 16, spreadRadius: 1)]
            : [],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isLive ? Colors.red.withOpacity(0.15) : Colors.white10,
              child: Icon(
                isLive ? Icons.podcasts_rounded : Icons.event_note_rounded,
                color: isLive ? Colors.red : Colors.white54,
              ),
            ),
            if (isLive)
              Positioned(
                right: 0, top: 0,
                child: Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 600.ms).then().fadeOut(duration: 600.ms),
              ),
          ],
        ),
        title: Text(cls.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(cls.teacherName, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            if (isLive) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Text('LIVE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ).animate(onPlay: (c) => c.repeat()).fade(begin: 0.6, end: 1.0, duration: 800.ms),
                ],
              ),
            ],
          ],
        ),
        trailing: isLive
            ? ElevatedButton(
                onPressed: () async {
                  if (context.mounted) {
                    context.push('/live_stream/${cls.id}');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTeacher ? AppColors.primary : Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isTeacher ? 'Stream' : 'Join'),
              )
            : isTeacher
                ? OutlinedButton(
                    onPressed: () async {
                      await ref.read(liveClassesProvider.notifier).startClass(cls.id);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Start'),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Upcoming', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
      ),
    ).animate().fadeIn(delay: (60 * index).ms).slideX(begin: 0.05);
  }
}

