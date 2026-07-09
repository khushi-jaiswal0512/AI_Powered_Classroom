import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/live_class_provider.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import '../../../dashboard/providers/batch_provider.dart';
import '../../../../data/models/batch.dart';

class CreateClassDialog extends ConsumerStatefulWidget {
  const CreateClassDialog({super.key});

  @override
  ConsumerState<CreateClassDialog> createState() => _CreateClassDialogState();
}

class _CreateClassDialogState extends ConsumerState<CreateClassDialog> {
  final _titleController = TextEditingController();
  int? _selectedBatchId;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Watch the batches provider to populate the dropdown
    final batchesAsync = ref.watch(myBatchesProvider);

    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create Live Class',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Class Title',
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: 'e.g. Advanced Algebra - Session 1',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // ✅ Target Batch Selection logic
            batchesAsync.when(
              data: (batches) => DropdownButtonFormField<int>(
                isExpanded: true, // Prevent overflow
                value: _selectedBatchId,
                dropdownColor: const Color(0xFF161B22),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Target Batch',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
              error: (err, _) => Text('Error loading batches: $err', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),

            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: (_isLoading || _titleController.text.isEmpty || _selectedBatchId == null)
                  ? null
                  : () async {
                      setState(() => _isLoading = true);
                      // ✅ Passing both title and batchId as required by the updated notifier
                      final classId = await ref.read(liveClassesProvider.notifier).createClass(
                        _titleController.text.trim(), 
                        _selectedBatchId!,
                      );
                      
                      if (mounted) {
                        if (classId != null) {
                          // Immediately start the class
                          final started = await ref.read(liveClassesProvider.notifier).startClass(classId);
                          
                          setState(() => _isLoading = false);
                          if (started) {
                            // 1. Refresh classes for the specific batch to ensure meeting details are fetched
                            await ref.read(liveClassesProvider.notifier).fetchClasses(batchId: _selectedBatchId!);
                            
                            // 2. Small sync delay for backend/Agora propagate
                            await Future.delayed(const Duration(milliseconds: 500));
                            
                            if (mounted) {
                              Navigator.pop(context); // Close dialog
                              context.push('/live_stream/$classId'); // Navigate to live room
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Class started successfully!'), backgroundColor: AppColors.success),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Class created, but Agora failed (Check Backend Credentials).'), 
                                backgroundColor: Colors.blueAccent
                              ),
                            );
                          }
                        } else {
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to create class. Possible DTO mismatch or unauthorized.'), 
                              backgroundColor: AppColors.error
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create Class', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

