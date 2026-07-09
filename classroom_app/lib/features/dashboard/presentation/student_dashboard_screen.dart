import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:developer' as dev;

import 'package:classroom_app/core/constants/app_colors.dart';
import '../providers/dashboard_provider.dart';
import 'package:classroom_app/data/services/api_service.dart';
import 'widgets/student_sidebar.dart';
import '../../ai_chat/presentation/chat_screen.dart';
import '../providers/batch_provider.dart';
import 'widgets/recommendation_widget.dart';

// (exploreBatchesProvider is now imported from batch_provider.dart)

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends ConsumerState<StudentDashboardScreen> {
  int _selectedIndex = 0; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Row(
        children: [
          StudentSidebar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
          ),
          Expanded(
            child: _buildSection(_selectedIndex)
                .animate(key: ValueKey(_selectedIndex))
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
        backgroundColor: const Color(0xFF6C63FF),
        onPressed: () => context.push('/doubt-room'),
        child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
      ) : null,
    );
  }

  Widget _buildSection(int index) {
    switch (index) {
      case 0: return const _StudentWorkspace();
      case 1: return const _ExploreCoursesSection(); 
      case 2: return const _MyJoinedBatchesSection(); 
      case 3: return const ChatScreen(); 
      default: return const _StudentWorkspace();
    }
  }
}

// --- 1. MAIN WORKSPACE (With Shimmer Effects) ---
class _StudentWorkspace extends ConsumerWidget {
  const _StudentWorkspace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashState = ref.watch(studentDashboardProvider);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Student Workspace', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () {
              ref.invalidate(studentDashboardProvider);
            },
          ),
        ],
      ),
      body: dashState.when(
        loading: () => Stack(
          children: [
            const Center(child: CircularProgressIndicator()),
            _buildShimmerOverlay(Colors.white.withOpacity(0.3)), 
          ],
        ),
        error: (err, _) => Stack(
          children: [
            Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
            _buildShimmerOverlay(Colors.redAccent), 
          ],
        ),
        data: (data) => Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                ref.refresh(studentDashboardProvider.future);
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionHeader(title: 'Live Classes', onAction: () => context.push('/live-classes')),
                    const SizedBox(height: 12),
                    const _LiveClassesSection(),
                    const SizedBox(height: 24),
                    
                    _SectionHeader(title: 'Your Progress'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _StatCard(title: 'Avg Score', value: '${data.averageScore.toStringAsFixed(1)}%', icon: Icons.auto_graph_rounded, color: AppColors.primary)),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(title: 'Quizzes Taken', value: '${data.totalQuizzesTaken}', icon: Icons.quiz_rounded, color: Colors.orange)),
                      ],
                    ).animate().fadeIn().slideY(begin: 0.1),
                    
                    const SizedBox(height: 20),
                    _AttendanceCard(pct: data.attendancePercentage, attended: data.attendedClasses, total: data.totalClasses).animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 24),

                    // ✅ AI Recommendation Widget (auto-hides when empty)
                    const RecommendationWidget(),

                    _SectionHeader(title: 'Continue Learning', onAction: () => context.push('/videos')),
                    const SizedBox(height: 12),
                    _VideoListSection(videos: data.recentVideos), 
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            _buildShimmerOverlay(Colors.white.withOpacity(0.2)), 
          ],
        ),
      ),
    );
  }
}

// --- 2. EXPLORE COURSES SECTION ---
class _ExploreCoursesSection extends ConsumerWidget {
  const _ExploreCoursesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(exploreBatchesProvider);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Explore Courses', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: batchesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text('Failed to load courses: $err', style: const TextStyle(color: Colors.white70)),
                    TextButton(onPressed: () => ref.invalidate(exploreBatchesProvider), child: const Text('Retry', style: TextStyle(color: Color(0xFF6C63FF))))
                  ],
                ),
              ),
              data: (batches) {
                if (batches.isEmpty) {
                  return const Center(child: Text('No courses available to explore.', style: TextStyle(color: Colors.white38)));
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 1.1,
                  ),
                  itemCount: batches.length,
                  itemBuilder: (context, index) {
                    final batch = batches[index];
                    return _CourseExploreCard(
                      title: batch.name,
                      teacherName: batch.teacherName,
                      batchName: batch.subject,
                      batchCode: batch.batchCode,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseExploreCard extends ConsumerWidget {
  final String title;
  final String teacherName;
  final String batchName;
  final String batchCode;

  const _CourseExploreCard({
    required this.title, 
    required this.teacherName,
    required this.batchName, 
    required this.batchCode
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.play_lesson_rounded, color: Color(0xFF6C63FF), size: 28),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('Teacher: $teacherName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text('Batch: $batchName', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF), 
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: batchCode.isEmpty ? null : () async {
              try {
                final success = await ref.read(batchProvider).joinBatch(batchCode);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined $batchName!'), backgroundColor: Colors.green));
                  ref.invalidate(studentDashboardProvider);
                  ref.invalidate(myBatchesProvider);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
                }
              }
            },
            child: const Text('Join Batch', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// --- 3. MY JOINED BATCHES SECTION ---
class _MyJoinedBatchesSection extends ConsumerWidget {
  const _MyJoinedBatchesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myBatchesState = ref.watch(myBatchesProvider);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Joined Batches', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: myBatchesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
              data: (batches) {
                if (batches.isEmpty) {
                  return const Center(
                    child: Text('You haven\'t joined any batches yet. Go to "Explore Courses"!', 
                    style: TextStyle(color: Colors.white38)),
                  );
                }

                return ListView.builder(
                  itemCount: batches.length,
                  itemBuilder: (context, index) {
                    final batch = batches[index];
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF6C63FF),
                          child: Icon(Icons.check_circle_rounded, color: Colors.white),
                        ),
                        title: Text(batch.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('Status: Active Enrollment', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
                        onTap: () => context.push('/batch/${batch.id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- HELPER UI WIDGETS ---

class _VideoListSection extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> videos;
  const _VideoListSection({required this.videos});

  @override
  ConsumerState<_VideoListSection> createState() => _VideoListSectionState();
}

class _VideoListSectionState extends ConsumerState<_VideoListSection> {
  final Map<String, bool> _quizExistsMap = {};

  @override
  void initState() {
    super.initState();
    _checkQuizzes();
  }

  @override
  void didUpdateWidget(_VideoListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videos != widget.videos) {
      _checkQuizzes();
    }
  }

  Future<void> _checkQuizzes() async {
    final api = ref.read(apiServiceProvider);
    for (var video in widget.videos) {
      final videoId = video['id'].toString();
      if (!_quizExistsMap.containsKey(videoId)) {
        try {
          // ✅ FIX: use getQuizForVideo directly (checkQuizExists had wrong URL prefix)
          final res = await api.getQuizForVideo(videoId);
          bool exists = false;
          if (res['success'] == true && res['data'] != null) {
            final data = res['data'];
            final questions = (data is Map)
                ? (data['questions'] ?? data['data']?['questions'])
                : null;
            exists = questions is List && questions.isNotEmpty;
          }
          if (mounted) {
            setState(() => _quizExistsMap[videoId] = exists);
          }
        } catch (_) {
          if (mounted) setState(() => _quizExistsMap[videoId] = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            "No saved videos found. Teacher must click 'Save & Publish'.", 
            style: TextStyle(color: Colors.white54, fontSize: 13)
          )
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.videos.length,
        itemBuilder: (context, i) {
          final video = widget.videos[i];
          final videoId = video['id'].toString();
          final hasQuiz = _quizExistsMap[videoId];
          
          return Container(
            width: 260,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: Column(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _playVideo(context, ref, videoId),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: const Center(child: Icon(Icons.play_circle_fill, size: 54, color: Colors.white70)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Text(video['title'] ?? 'Lecture', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(icon: const Icon(Icons.description, color: Colors.blueAccent, size: 22), tooltip: 'Transcript', onPressed: () => context.push('/video/transcript/$videoId')),
                          IconButton(icon: const Icon(Icons.download, color: Colors.greenAccent, size: 22), tooltip: 'Download', onPressed: () => _download(context, ref, videoId)),
                          if (hasQuiz == true)
                            IconButton(
                              icon: const Icon(Icons.play_arrow, color: Colors.orangeAccent, size: 22), // ▶
                              tooltip: 'Start Quiz',
                              onPressed: () => context.push('/quiz/$videoId'),
                            )
                          else if (hasQuiz == false)
                            const Tooltip(
                              message: 'Quiz not generated yet',
                              child: Icon(Icons.quiz_outlined, color: Colors.white24, size: 22),
                            )
                          else
                            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _playVideo(BuildContext context, WidgetRef ref, String id) async {
    try {
      // ✅ Fix 1: Use getPlaybackUrl
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fetching secure link...'), duration: Duration(seconds: 1)));
      final res = await ref.read(apiServiceProvider).getPlaybackUrl(id);
      final playableUrl = res['data']['url'];
      if (playableUrl != null) {
        // Use the proper route with path parameters
        context.push('/video/player/$id');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot play video: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _download(BuildContext context, WidgetRef ref, String id) async {
    try {
      final res = await ref.read(apiServiceProvider).getVideoDownloadUrl(id);
      // ✅ FIX: field is 'downloadUrl' (not 'url') after api_service fix
      final downloadUrl = res['data']?['downloadUrl'] ?? res['data']?['url'];
      if (downloadUrl != null && downloadUrl.toString().isNotEmpty) {
        await launchUrl(Uri.parse(downloadUrl.toString()), mode: LaunchMode.externalApplication);
      } else {
        throw Exception('No download URL in response');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title; final String value; final IconData icon; final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 12), Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)), Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12))]));
  }
}

class _AttendanceCard extends StatelessWidget {
  final double pct; final int attended; final int total;
  const _AttendanceCard({required this.pct, required this.attended, required this.total});
  @override
  Widget build(BuildContext context) {
    final color = pct >= 75 ? Colors.greenAccent : pct >= 50 ? Colors.orangeAccent : Colors.redAccent;
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Attendance', style: TextStyle(color: Colors.white54, fontSize: 12)), Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)), Text('$attended of $total classes', style: const TextStyle(color: Colors.white38, fontSize: 11))])), CircularProgressIndicator(value: pct/100, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(color), strokeWidth: 8)]));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title; final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), if (onAction != null) TextButton(onPressed: onAction, child: const Text('View All', style: TextStyle(color: Color(0xFF6C63FF))))]);
  }
}

class _LiveClassesSection extends StatelessWidget {
  const _LiveClassesSection();
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Row(children: [const Icon(Icons.live_tv_rounded, color: Colors.blueAccent), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Active Live Classes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text('Join now to attend', style: TextStyle(color: Colors.white54, fontSize: 12))])), ElevatedButton(onPressed: () => context.push('/live-classes'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white), child: const Text('JOIN'))]));
  }
}

// ✅ GLOBAL SHIMMER OVERLAY HELPER
Widget _buildShimmerOverlay(Color color) {
  return IgnorePointer(
    child: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.3, 0.5, 0.7],
          colors: [
            Colors.transparent,
            color,
            Colors.transparent,
          ],
        ),
      ),
    ) 
    .animate()
    .shimmer(
      duration: 1200.ms,
      color: color.withOpacity(0.5),
      angle: 45,
    )
    .fadeOut(duration: 400.ms),
  );
}
