import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import '../providers/live_class_provider.dart';
import '../../dashboard/providers/batch_provider.dart';

class CreateClassScreen extends ConsumerStatefulWidget {
  const CreateClassScreen({super.key});

  @override
  ConsumerState<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends ConsumerState<CreateClassScreen> {
  final _titleController = TextEditingController();
  int? _selectedBatchId;
  bool _isLoading = false;

  void _handleCreate() async {
    if (_titleController.text.trim().isNotEmpty && _selectedBatchId != null) {
      setState(() => _isLoading = true);
      // ✅ Updated to pass both required arguments: title and batchId
      final success = await ref.read(liveClassesProvider.notifier).createClass(
        _titleController.text.trim(),
        _selectedBatchId!,
      );
      
      if (mounted) {
        setState(() => _isLoading = false);
        if (success != null && success.isNotEmpty) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Class Created successfully!'), backgroundColor: AppColors.success),
          );
        } else {
          // If creation failed, it might be due to 400 DTO error or 500 Agora error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create class. Please check if your account is a TEACHER or contact support.'), 
              backgroundColor: Colors.redAccent
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Watch the batches provider for selection
    final batchesAsync = ref.watch(myBatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create New Class')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.cast_for_education, size: 60, color: AppColors.primary)
                .animate().fadeIn().scale(),
            const SizedBox(height: 32),
            TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Class Topic / Title',
                prefixIcon: Icon(Icons.topic),
              ),
            ).animate().fadeIn().slideY(),
            const SizedBox(height: 16),

            // ✅ Batch Selection Dropdown
            batchesAsync.when(
              data: (batches) => DropdownButtonFormField<int>(
                isExpanded: true, // Prevent overflow
                value: _selectedBatchId,
                decoration: const InputDecoration(
                  labelText: 'Target Batch',
                  prefixIcon: Icon(Icons.group_work_rounded),
                ),
                items: batches.map<DropdownMenuItem<int>>((batch) {
                  return DropdownMenuItem<int>(
                    value: batch.id,
                    child: Text(batch.name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedBatchId = val),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Error loading batches: $err', style: const TextStyle(color: Colors.redAccent)),
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: (_isLoading || _titleController.text.isEmpty || _selectedBatchId == null)
                  ? null 
                  : _handleCreate,
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create & Schedule'),
            ).animate().fadeIn().scale(),
          ],
        ),
      ),
    );
  }
}

