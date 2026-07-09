import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/upload_provider.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import '../../../../data/models/batch.dart';

import '../../../dashboard/providers/batch_provider.dart';

class UploadVideoDialog extends ConsumerStatefulWidget {
  const UploadVideoDialog({super.key});

  @override
  ConsumerState<UploadVideoDialog> createState() => _UploadVideoDialogState();
}

class _UploadVideoDialogState extends ConsumerState<UploadVideoDialog> {
  final _titleController = TextEditingController();
  final _transcriptController = TextEditingController();
  PlatformFile? _selectedFile;
  int? _localBatchId;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: true,
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _transcriptController.dispose();
    // ref.read(uploadProvider.notifier).reset(); // 🔥 Fix: Removed ref usage in dispose to prevent crash
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadProvider);
    final batchesAsync = ref.watch(myBatchesProvider);

    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upload New Video',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // ✅ Added: Batch Selector
              batchesAsync.when(
                data: (batches) => DropdownButtonFormField<int>(
                  isExpanded: true, // Prevent overflow
                  value: _localBatchId,
                  dropdownColor: const Color(0xFF161B22),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Select Target Batch',
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
                  onChanged: (val) {
                    setState(() => _localBatchId = val);
                    if (val != null) {
                      ref.read(uploadProvider.notifier).setBatch(val);
                    }
                  },
                ),
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (err, _) => Text('Error loading batches: $err', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Video Title',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _transcriptController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Transcript (Optional)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedFile != null ? AppColors.secondary : Colors.white12,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                        color: _selectedFile != null ? AppColors.secondary : Colors.white38,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFile?.name ?? 'Select Video File',
                        style: TextStyle(
                          color: _selectedFile != null ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_selectedFile != null)
                        Text(
                          '${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                          style: const TextStyle(color: Colors.white24, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),

              if (uploadState.isUploading) ...[
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  backgroundColor: Colors.white10,
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 8),
                Text(
                  uploadState.progress ?? 'Uploading...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],

              if (uploadState.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  uploadState.error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: (uploadState.isUploading || (uploadState.isS3Uploaded ? (_titleController.text.isEmpty || _localBatchId == null) : _selectedFile == null))
                    ? null
                    : () async {
                        if (_localBatchId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a target batch first')),
                          );
                          return;
                        }

                        if (!uploadState.isS3Uploaded) {
                          // Phase 1: Upload to S3
                          await ref.read(uploadProvider.notifier).performS3Upload(
                                _selectedFile!.bytes!,
                                _selectedFile!.name,
                              );
                        } else {
                          // Phase 2: Save Metadata
                          final success = await ref.read(uploadProvider.notifier).finalizeMetadata(
                                _titleController.text.trim(),
                                transcript: _transcriptController.text.trim(), // Defaults to "" via trim()
                              );
                          if (success && mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Video saved and published!'), backgroundColor: AppColors.success),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: uploadState.isS3Uploaded ? AppColors.secondary : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  uploadState.isS3Uploaded ? 'Save & Publish' : 'Start Upload',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

