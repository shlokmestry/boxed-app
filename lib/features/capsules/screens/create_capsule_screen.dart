import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/features/capsules/providers/capsule_provider.dart';
import 'package:boxed_app/features/capsules/services/capsule_service.dart';
import 'package:boxed_app/features/memories/services/memory_service.dart';
import 'package:boxed_app/core/services/encryption_service.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';

class CreateCapsuleScreen extends StatefulWidget {
  const CreateCapsuleScreen({super.key});

  @override
  State<CreateCapsuleScreen> createState() => _CreateCapsuleScreenState();
}

class _CreateCapsuleScreenState extends State<CreateCapsuleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _noteController = TextEditingController();
  final _picker = ImagePicker();

  DateTime? _unlockDate;
  String _emoji = '📦';
  bool _isLoading = false;
  final List<File> _selectedImages = [];

  final List<String> _emojis = ['📦', '🔒', '💌', '🎁', '⏳', '🌟', '🎉', '❤️'];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _noteController.dispose();
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(minutes: 5)),
      lastDate: DateTime(now.year + 10),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            surface: AppTheme.cardDark2,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            surface: AppTheme.cardDark2,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    setState(() {
      _unlockDate = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_unlockDate == null) {
      _showSnack('Please set an unlock date');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user!.$id;
      final userMasterKey = UserCryptoState.userMasterKey;

      // 1. Generate capsule key
      final capsuleKey = await EncryptionService.generateCapsuleKey();
      final encryptedKey = await EncryptionService.encryptCapsuleKey(
        capsuleKey: capsuleKey,
        userMasterKey: userMasterKey,
      );

      // 2. Create capsule in Appwrite
      final capsuleService = CapsuleService();
      final capsuleData = await capsuleService.createCapsuleWithKey(
        userId: userId,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        unlockDate: _unlockDate!,
        emoji: _emoji,
        encryptedCapsuleKey: encryptedKey,
      );

      final capsuleId = capsuleData['capsuleId'] as String;

      // 3. Save text note if any
      final note = _noteController.text.trim();
      if (note.isNotEmpty) {
        final memoryService = MemoryService();
        await memoryService.addTextMemory(
          capsuleId: capsuleId,
          userId: userId,
          text: note,
          capsuleKey: capsuleKey,
        );
      }

      // 4. Save photos if any
      if (_selectedImages.isNotEmpty) {
        final memoryService = MemoryService();
        for (final image in _selectedImages) {
          await memoryService.addPhotoMemory(
            capsuleId: capsuleId,
            userId: userId,
            imageFile: image,
            capsuleKey: capsuleKey,
          );
        }
      }

      // 5. Update provider
      context.read<CapsuleProvider>().addCapsule(capsuleData);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to create capsule: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.cardDark2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Capsule',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [

                  // Emoji picker
                  _label('Choose an emoji'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _emojis.length,
                      itemBuilder: (_, i) {
                        final e = _emojis[i];
                        final selected = e == _emoji;
                        return GestureDetector(
                          onTap: () => setState(() => _emoji = e),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 10),
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : AppTheme.cardDark2,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(e, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Capsule name
                  _label('Capsule Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('Name it like a movie title'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 20),

                  // Description
                  _label('Description (optional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    maxLength: 300,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('What belongs in here?').copyWith(
                      counterStyle: const TextStyle(color: AppTheme.mutedText2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Unlock date
                  _label('Unlock Date'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _unlockDate == null
                                  ? 'Set a date and time'
                                  : DateFormat('MMM d, yyyy • h:mm a')
                                      .format(_unlockDate!),
                              style: TextStyle(
                                color: _unlockDate == null
                                    ? AppTheme.mutedText2 : Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Icon(Icons.calendar_today,
                              color: AppTheme.mutedText2, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The capsule locks immediately and opens on this date.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                  const SizedBox(height: 28),

                  // Note
                  _label('Add a Note (optional)'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: TextField(
                      controller: _noteController,
                      maxLines: 5,
                      minLines: 3,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.5),
                      decoration: const InputDecoration(
                        hintText: 'Write something to your future self...',
                        hintStyle: TextStyle(color: AppTheme.mutedText2),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Photos
                  Row(
                    children: [
                      _label('Photos (optional)'),
                      const Spacer(),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
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
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_selectedImages.isEmpty)
                    Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Center(
                        child: Text('No photos added yet',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 13)),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                            child: Image.file(_selectedImages[i],
                                fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedImages.removeAt(i)),
                              child: Container(
                                width: 22, height: 22,
                                decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '🔒 Everything is encrypted the moment you tap Create.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Create button
            Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 0, 24, 20 + MediaQuery.of(context).padding.bottom),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _create,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create Capsule',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.mutedText,
          fontSize: 13,
          fontWeight: FontWeight.w500));

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.mutedText2),
        filled: true,
        fillColor: AppTheme.cardDark2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.red),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}