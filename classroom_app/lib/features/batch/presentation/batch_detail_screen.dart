import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/batch_content_views.dart';

class BatchDetailScreen extends StatefulWidget {
  final int batchId;
  final int initialTab;
  const BatchDetailScreen({super.key, required this.batchId, this.initialTab = 0});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E202C),
        elevation: 0,
        title: const Text('Batch Content'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6B4EFF),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: '🎥 Videos'),
            Tab(text: '🧠 Quizzes'),
            Tab(text: '📡 Live Classes'),
            Tab(text: '🤖 AI Doubt Solver'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // MANDATORY: Only fetch videos for THIS batchId
          BatchVideosView(batchId: widget.batchId), 
          
          BatchQuizzesView(batchId: widget.batchId),
          
          BatchLiveClassesView(batchId: widget.batchId),
          
          // AI Solver passes batch context to backend
          AIDoubtSolverView(batchId: widget.batchId), 
        ],
      ),
    );
  }
}
