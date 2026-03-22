import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:boxed_app/core/state/capsule_crypto_state.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/features/memories/services/memory_service.dart';

class AddMemoryScreen extends StatefulWidget {
  final String capsuleId;
  const AddMemoryScreen({super.key, required this.capsuleId});

  @override
  State<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends State<AddMemoryScreen> {
  final _textController = TextEditingController();
  final _memoryService = MemoryService();
  final _picker = ImagePicker();

  bool _isSaving = false;
  final List<File> _selectedImages = [];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _selectedImages.add(File(picked.path)));
    }
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a note or photo first'),
          backgroundColor: AppTheme.cardDark2,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user!.$id;
      final capsuleKey = CapsuleCryptoState.getKey(widget.capsuleId);

      // Save text memory
      if (text.isNotEmpty) {
        await _memoryService.addTextMemory(
          capsuleId: widget.capsuleId,
          userId: userId,
          text: text,
          capsuleKey: capsuleKey,
        );
      }

      // Save photo memories
      for (final image in _selectedImages) {
        await _memoryService.addPhotoMemory(
          capsuleId: widget.capsuleId,
          userId: userId,
          imageFile: image,
          capsuleKey: capsuleKey,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Add Memory',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Text note
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardDark2,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _textController,
              maxLines: 8,
              minLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
              decoration: const InputDecoration(
                hintText: 'Write something to your future self...',
                hintStyle: TextStyle(color: AppTheme.mutedText2),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Photos section
          Row(
            children: [
              const Text('Photos',
                  style: TextStyle(color: AppTheme.mutedText,
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Add Photo',
                          style: TextStyle(color: Colors.white,
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_selectedImages.isEmpty)
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.cardDark2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_outlined,
                        color: Colors.white.withOpacity(0.3), size: 32),
                    const SizedBox(height: 8),
                    Text('No photos added yet',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.3), fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _selectedImages.length,
              itemBuilder: (_, i) => Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_selectedImages[i], fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImages.removeAt(i)),
                      child: Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                            color: Colors.black, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 40),
          Text(
            '🔒 Everything is encrypted before saving.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.35), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}