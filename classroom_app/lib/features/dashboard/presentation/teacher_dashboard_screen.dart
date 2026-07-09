import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import 'widgets/teacher_sidebar.dart';
import '../../video/presentation/widgets/upload_video_dialog.dart';
import '../../live_class/presentation/widgets/create_class_dialog.dart';
import '../providers/dashboard_provider.dart';
import '../../video/providers/video_library_provider.dart';
import '../../live_class/providers/live_class_provider.dart';
import '../../ai_chat/presentation/chat_screen.dart';

// ✅ Added imports for Batch Management
import '../providers/batch_provider.dart';
import 'package:classroom_app/data/services/api_service.dart';

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends ConsumerState<TeacherDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Row(
        children: [
          TeacherSidebar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              // ✅ Updated Profile to index 5 to match new sidebar layout
              if (index == 5) {
                context.push('/profile');
              } else {
                setState(() => _selectedIndex = index);
              }
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
    );
  }

  Widget _buildSection(int index) {
    switch (index) {
      case 0: return const _OverviewSection();
      case 1: return const _BatchManagementSection(); // ✅ Added Batch Section
      case 2: return const _VideoManagementSection();
      case 3: return const _LiveClassSection();
      case 4: return const ChatScreen(); // ✅ AI Help Room is now at index 4
      default: return const _OverviewSection();
    }
  }
}

// --- 1. OVERVIEW SECTION ---
class _OverviewSection extends ConsumerWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashState = ref.watch(teacherDashboardProvider);

    return dashState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard Overview', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            
            // Stats Row
            Row(
              children: [
                _StatCard(title: 'Total Classes', value: data.totalClassesCreated.toString(), icon: Icons.class_rounded, color: Colors.blue),
                const SizedBox(width: 24),
                _StatCard(title: 'Total Students', value: data.totalStudents.toString(), icon: Icons.people_rounded, color: Colors.purple),
                const SizedBox(width: 24),
                _StatCard(title: 'Avg Attendance', value: '${data.averageAttendancePerClass.toStringAsFixed(1)}%', icon: Icons.how_to_reg_rounded, color: Colors.green),
                const SizedBox(width: 24),
                _StatCard(title: 'Avg Score', value: '${data.averageStudentScore.toStringAsFixed(1)}%', icon: Icons.summarize_rounded, color: Colors.orange),
              ],
            ),
            
            const SizedBox(height: 48),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weak Topics
                Expanded(
                  flex: 1,
                  child: _CardContainer(
                    title: 'Weak Topics',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: data.mostCommonWeakTopics.isEmpty 
                        ? [const Text('No data yet', style: TextStyle(color: Colors.white38))]
                        : data.mostCommonWeakTopics.map((t) => Chip(
                            label: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            backgroundColor: Colors.white.withOpacity(0.05),
                          )).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Recent Classes
                Expanded(
                  flex: 1,
                  child: _CardContainer(
                    title: 'Recent Classes',
                    child: Column(
                      children: data.recentClasses.isEmpty
                        ? [const Text('No recent classes', style: TextStyle(color: Colors.white38))]
                        : data.recentClasses.map((c) => ListTile(
                            leading: const Icon(Icons.circle, size: 8, color: Colors.blue),
                            title: Text(c['title'] ?? 'Class', style: const TextStyle(color: Colors.white, fontSize: 14)),
                            subtitle: Text(c['date'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          )).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- 2. BATCH MANAGEMENT SECTION (NEW) ---
class _BatchManagementSection extends ConsumerWidget {
  const _BatchManagementSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(myBatchesProvider);

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Batches', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showCreateBatchDialog(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Batch'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          Expanded(
            child: batchesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
              data: (batches) {
                if (batches.isEmpty) {
                  return const Center(child: Text('No batches created yet. Click "Create Batch" to start.', style: TextStyle(color: Colors.white54)));
                }
                
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, 
                    crossAxisSpacing: 24, 
                    mainAxisSpacing: 24,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: batches.length,
                  itemBuilder: (context, index) {
                    final batch = batches[index];
                    return _BatchCard(
                      name: batch.name,
                      subject: batch.subject,
                      batchCode: batch.batchCode ?? 'N/A', 
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

  void _showCreateBatchDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF161B22),
            title: const Text('Create New Batch', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Batch Name', labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Subject', labelStyle: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                onPressed: isLoading ? null : () async {
                  if (nameController.text.isEmpty || subjectController.text.isEmpty) return;
                  
                  setState(() => isLoading = true);
                  try {
                    final response = await ref.read(apiServiceProvider).createBatch(nameController.text.trim(), subjectController.text.trim());
                    
                    ref.invalidate(myBatchesProvider); // Refresh the list
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      final code = response['data']['batchCode'];
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Batch Created! Code: $code'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    setState(() => isLoading = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
                    }
                  }
                },
                child: isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                    : const Text('Create', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  final String name;
  final String subject;
  final String batchCode;

  const _BatchCard({required this.name, required this.subject, required this.batchCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(subject, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.key, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 8),
                Text(batchCode, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 3. VIDEO MANAGEMENT SECTION ---
class _VideoManagementSection extends ConsumerWidget {
  const _VideoManagementSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosState = ref.watch(videoLibraryProvider);

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Video Management', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              
              // ✅ Added: Batch Filter Dropdown
              SizedBox(
                width: 250,
                child: Consumer(
                  builder: (context, ref, child) {
                    final batchesAsync = ref.watch(myBatchesProvider);
                    final notifier = ref.read(videoLibraryProvider.notifier);
                    
                    return batchesAsync.when(
                      data: (batches) => DropdownButtonFormField<int?>(
                        isExpanded: true, // Prevent overflow
                        value: notifier.selectedBatchId,
                        dropdownColor: const Color(0xFF161B22),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Filter by Batch',
                          labelStyle: const TextStyle(color: Colors.white54),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All My Videos'),
                          ),
                          ...batches.map<DropdownMenuItem<int?>>((batch) {
                            return DropdownMenuItem<int?>(
                              value: batch.id,
                              child: Text(batch.name),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          ref.read(videoLibraryProvider.notifier).fetchVideos(batchId: val);
                        },
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => const SizedBox.shrink(),
                    );
                  }
                ),
              ),

              ElevatedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const UploadVideoDialog()),
                icon: const Icon(Icons.upload_rounded),
                label: const Text('Upload Video'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          Expanded(
            child: videosState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
              data: (videos) => videos.isEmpty
                ? const Center(child: Text('No videos uploaded yet.', style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: videos.length,
                    itemBuilder: (context, index) {
                      final video = videos[index];
                      // ✅ FIX: use transcript as primary truth (matches VideoDTO logic)
                      final bool isReady = (video.transcript != null && video.transcript!.isNotEmpty)
                          || video.transcriptionStatus.toUpperCase() == 'COMPLETED';
                      
                      return Card(
                        color: Colors.white.withOpacity(0.03),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(video.title, style: const TextStyle(color: Colors.white)),
                          // ✅ FIX: show uploadedAt (VideoDTO field name)
                          subtitle: Text('Uploaded: ${video.createdAt}', style: const TextStyle(color: Colors.white38)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                video.hasQuiz
                                  ? 'QUIZ READY'
                                  : (isReady ? 'TRANSCRIBED' : 'PENDING'),
                                style: TextStyle(
                                  color: video.hasQuiz
                                    ? Colors.green
                                    : (isReady ? Colors.blueAccent : Colors.orangeAccent),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold
                                )
                              ),
                              const SizedBox(width: 8),
                              
                              _QuizActionIcon(
                                videoId: video.id,
                                isReady: isReady,
                                hasQuiz: video.hasQuiz,
                              ),

                              IconButton(
                                icon: const Icon(Icons.download_rounded, color: Colors.white54),
                                onPressed: () async {
                                  final url = await ref.read(videoLibraryProvider.notifier).getDownloadUrl(video.id);
                                  if (url != null) {
                                    final uri = Uri.parse(url);
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                                tooltip: 'Download Video',
                              ),
                              IconButton(
                                icon: const Icon(Icons.play_circle_outline, color: Colors.greenAccent),
                                onPressed: () => context.push('/video/player/${video.id}'),
                                tooltip: 'Play Video',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 4. LIVE CLASS SECTION ---
class _LiveClassSection extends ConsumerWidget {
  const _LiveClassSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesState = ref.watch(liveClassesProvider);

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Classes', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const CreateClassDialog()),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Class'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Expanded(
            child: classesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
              data: (classes) => classes.isEmpty
                ? const Center(child: Text('No classes created yet.', style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: classes.length,
                    itemBuilder: (context, index) {
                      final cls = classes[index];
                      return Card(
                        color: Colors.white.withOpacity(0.03),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: cls.isLive ? const _PulseIndicator() : const Icon(Icons.circle_outlined, color: Colors.white24, size: 12),
                          title: Text(cls.title, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(cls.isLive ? 'LIVE NOW' : 'Scheduled', style: TextStyle(color: cls.isLive ? Colors.red : Colors.white24, fontWeight: FontWeight.bold)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!cls.isLive)
                                ElevatedButton(
                                  onPressed: () async {
                                    // 1. Start the class
                                    await ref.read(liveClassesProvider.notifier).startClass(cls.id);
                                    
                                    // 2. Small delay for backend to generate meeting details
                                    await Future.delayed(const Duration(seconds: 1));
                                    
                                    // 3. Auto-navigate to the stream
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Starting broadcast...'), backgroundColor: Colors.green),
                                      );
                                      context.push('/live_stream/${cls.id}');
                                    }
                                  },
                                  child: const Text('Start Class'),
                                ),
                              if (cls.isLive)
                                ElevatedButton(
                                  onPressed: () async {
                                    final tokenData = await ref.read(liveClassesProvider.notifier).getClassToken(cls.id);
                                    if (tokenData != null && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joining class as HOST...')));
                                      context.push('/live_stream/${cls.id}');
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text('Join as Host'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- HELPER UI WIDGETS ---

// ✅ FIXED: Uses transcript as primary truth + adds Trigger Transcription for PENDING
class _QuizActionIcon extends ConsumerStatefulWidget {
  final dynamic videoId;
  final bool isReady;     // true = transcript exists OR status == COMPLETED
  final bool hasQuiz;

  const _QuizActionIcon({
    required this.videoId,
    required this.isReady,
    required this.hasQuiz,
  });

  @override
  ConsumerState<_QuizActionIcon> createState() => _QuizActionIconState();
}

class _QuizActionIconState extends ConsumerState<_QuizActionIcon> {
  bool _isGenerating = false;
  bool _isTranscribing = false;
  late bool _hasQuiz;

  @override
  void initState() {
    super.initState();
    _hasQuiz = widget.hasQuiz;
  }

  @override
  void didUpdateWidget(covariant _QuizActionIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ FIX: Only overwrite if the new data actually confirms a state change
    // Avoid "downgrading" to false if we just successfully generated it locally
    if (widget.hasQuiz && !oldWidget.hasQuiz) {
      _hasQuiz = true;
    } else if (!widget.hasQuiz && oldWidget.hasQuiz) {
       // Only downgrade if the source of truth explicitly says it's gone
       _hasQuiz = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── PENDING: show Trigger Transcription button ─────────────────────────
    if (!widget.isReady) {
      if (_isTranscribing) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
        );
      }
      return IconButton(
        icon: const Icon(Icons.transcribe_rounded, color: Colors.orangeAccent),
        tooltip: 'Trigger Transcription',
        onPressed: () async {
          setState(() => _isTranscribing = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Triggering transcription...')),
          );
          try {
            final api = ref.read(apiServiceProvider);
            await api.generateTranscript(widget.videoId.toString());
            ref.invalidate(videoLibraryProvider);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Transcription started! Refresh in a moment.'), backgroundColor: Colors.green),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
              );
            }
          } finally {
            if (mounted) setState(() => _isTranscribing = false);
          }
        },
      );
    }

    // ── Ready: show Generate and View buttons ──────────────────────────────
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Generate Quiz Button (Always show if transcribed)
        _isGenerating
            ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.star, color: Colors.orange),
                tooltip: 'Generate Quiz',
                onPressed: () async {
                  setState(() => _isGenerating = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generating Quiz... Please wait.')),
                  );
                  try {
                    final success = await ref
                        .read(videoLibraryProvider.notifier)
                        .generateQuiz(widget.videoId.toString());
                    if (success && mounted) {
                      setState(() => _hasQuiz = true);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '✅ Quiz generated!' : 'Failed to generate quiz'),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isGenerating = false);
                  }
                },
              ),

        // 2. View Quiz Button (Show only if at least one quiz exists)
        if (_hasQuiz)
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.green),
            tooltip: 'View Quiz',
            onPressed: () => context.push('/quiz/${widget.videoId}'),
          ),
      ],
    );
  }
}
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 16),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final String title;
  final Widget child;

  const _CardContainer({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseIndicator extends StatefulWidget {
  const _PulseIndicator();

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(1 - _controller.value),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.5 * (1 - _controller.value)),
                spreadRadius: 8 * _controller.value,
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
            ),
          ),
        );
      },
    );
  }
}
