import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import '../providers/upload_provider.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _transcriptController = TextEditingController();
  
  Uint8List? _videoBytes;
  String? _videoName;

  @override
  void dispose() {
    _titleController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: true, // Crucial for getting bytes on all platforms
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _videoBytes = result.files.single.bytes;
        _videoName = result.files.single.name;
      });
    }
  }

  void _handleUpload() async {
    if (_formKey.currentState!.validate() && _videoBytes != null) {
      final success = await ref.read(uploadProvider.notifier).uploadVideo(
            _titleController.text,
            _videoBytes!,
            _videoName!,
            transcript: _transcriptController.text.isNotEmpty ? _transcriptController.text : null,
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video uploaded successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context); // Go back
      } else if (mounted) {
        final error = ref.read(uploadProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Upload failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else if (_videoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a video file first.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: uploadState.isUploading ? null : _pickVideo,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _videoBytes != null ? AppColors.primary : AppColors.border,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _videoBytes != null ? Icons.video_file : Icons.cloud_upload_outlined,
                          size: 48,
                          color: _videoBytes != null ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _videoName ?? 'Tap to select video',
                          style: TextStyle(
                            color: _videoBytes != null ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1),
              
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Video Title',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Enter a title' : null,
              ).animate().fadeIn(delay: 200.ms),
              
              const SizedBox(height: 16),
              TextFormField(
                controller: _transcriptController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Transcript (Optional)',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 60.0),
                    child: Icon(Icons.description),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
              
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: uploadState.isUploading ? null : _handleUpload,
                child: uploadState.isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Uploading...'),
                        ],
                      )
                    : const Text('Upload Video'),
              ).animate().fadeIn(delay: 400.ms).scale(),
            ],
          ),
        ),
      ),
    );
  }
}

