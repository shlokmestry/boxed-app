import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _messageController = TextEditingController();
  final _picker = ImagePicker();

  DateTime? _unlockDate;
  String _emoji = '📦';
  bool _isLoading = false;
  final List<File> _selectedImages = [];
  int? _coverIndex;

  final List<String> _quickEmojis = [
    '📦', '🔒', '💌', '🎁', '⏳', '🌟', '🎉', '❤️'
  ];

  final List<String> _allEmojis = [
    '📦', '🔒', '💌', '🎁', '⏳', '🌟', '🎉', '❤️',
    '🌍', '🏔️', '🌊', '🌸', '🍂', '☃️', '🌙', '☀️',
    '🎵', '🎬', '📸', '✈️', '🏠', '🐾', '🦋', '🌈',
    '🔑', '💎', '🕰️', '📖', '🧭', '🪄', '🎭', '🏆',
    '🌺', '🍀', '💫', '🔮', '🧸', '🪞', '🎪', '🛸',
  ];

  bool get _hasContent =>
      _nameController.text.trim().isNotEmpty ||
      _messageController.text.trim().isNotEmpty ||
      _selectedImages.isNotEmpty ||
      _unlockDate != null;

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasContent) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard capsule?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Everything you\'ve added will be lost.',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing',
                style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(picked.map((x) => File(x.path)));
        _coverIndex ??= 0;
      });
    }
  }

  void _showEmojiGrid() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Pick an emoji',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: _allEmojis.length,
              itemBuilder: (_, i) {
                final e = _allEmojis[i];
                final selected = e == _emoji;
                return GestureDetector(
                  onTap: () {
                    setState(() => _emoji = e);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : AppTheme.cardDark2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 20))),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    await _showUnlockDatePicker();
  }

  Future<void> _showUnlockDatePicker() async {
    final now = DateTime.now();
    DateTime selectedDate = _unlockDate ?? now.add(const Duration(days: 30));
    int selectedHour = selectedDate.hour;
    int selectedMinute = (selectedDate.minute ~/ 5) * 5;

    final presets = [
      {'label': '1 Week', 'date': now.add(const Duration(days: 7))},
      {'label': '1 Month', 'date': DateTime(now.year, now.month + 1, now.day)},
      {'label': '3 Months', 'date': DateTime(now.year, now.month + 3, now.day)},
      {'label': '6 Months', 'date': DateTime(now.year, now.month + 6, now.day)},
      {'label': '1 Year', 'date': DateTime(now.year + 1, now.month, now.day)},
      {'label': '5 Years', 'date': DateTime(now.year + 5, now.month, now.day)},
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text('When does this open?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('Pick a date and time for the capsule to unlock.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.45), fontSize: 13)),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((p) {
                    final d = p['date'] as DateTime;
                    final isSelected = selectedDate.year == d.year &&
                        selectedDate.month == d.month &&
                        selectedDate.day == d.day;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedDate = d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : AppTheme.cardDark2,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(p['label'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: Colors.white.withOpacity(0.08), height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.white,
                        onPrimary: Colors.black,
                        surface: Color(0xFF111111),
                        onSurface: Colors.white,
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: selectedDate,
                      firstDate: now.add(const Duration(minutes: 5)),
                      lastDate: DateTime(now.year + 10),
                      onDateChanged: (d) =>
                          setModalState(() => selectedDate = d),
                    ),
                  ),
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.08), height: 1),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        color: Colors.white54, size: 18),
                    const SizedBox(width: 10),
                    Text('Unlock Time',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 14)),
                    const Spacer(),
                    _timeSpinner(
                      display: selectedHour.toString().padLeft(2, '0'),
                      onUp: () => setModalState(
                          () => selectedHour = (selectedHour + 1) % 24),
                      onDown: () => setModalState(
                          () => selectedHour = (selectedHour - 1 + 24) % 24),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(':',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                    ),
                    _timeSpinner(
                      display: selectedMinute.toString().padLeft(2, '0'),
                      onUp: () => setModalState(
                          () => selectedMinute = (selectedMinute + 5) % 60),
                      onDown: () => setModalState(() =>
                          selectedMinute = (selectedMinute - 5 + 60) % 60),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 0, 24, 16 + MediaQuery.of(context).padding.bottom),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _unlockDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedHour,
                          selectedMinute,
                        );
                      });
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Set Unlock Date',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeSpinner({
    required String display,
    required VoidCallback onUp,
    required VoidCallback onDown,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
            onTap: onUp,
            child: const Icon(Icons.keyboard_arrow_up_rounded,
                color: Colors.white54, size: 24)),
        Container(
          width: 48, height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppTheme.cardDark2,
              borderRadius: BorderRadius.circular(8)),
          child: Text(display,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
        ),
        GestureDetector(
            onTap: onDown,
            child: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white54, size: 24)),
      ],
    );
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_unlockDate == null) {
      _showSnack('Please set an unlock date');
      return;
    }

    setState(() => _isLoading = true);

    // Capture navigator and messenger BEFORE async work
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user!.$id;
      final userMasterKey = UserCryptoState.userMasterKey;

      final capsuleKey = await EncryptionService.generateCapsuleKey();
      final encryptedKey = await EncryptionService.encryptCapsuleKey(
        capsuleKey: capsuleKey,
        userMasterKey: userMasterKey,
      );

      final capsuleService = CapsuleService();
      final capsuleData = await capsuleService.createCapsuleWithKey(
        userId: userId,
        name: _nameController.text.trim(),
        description: _messageController.text.trim(),
        unlockDate: _unlockDate!,
        emoji: _emoji,
        encryptedCapsuleKey: encryptedKey,
      );

      final capsuleId = capsuleData['capsuleId'] as String;

      final message = _messageController.text.trim();
      if (message.isNotEmpty) {
        await MemoryService().addTextMemory(
          capsuleId: capsuleId,
          userId: userId,
          text: message,
          capsuleKey: capsuleKey,
        );
      }

      if (_selectedImages.isNotEmpty) {
        final memSvc = MemoryService();
        for (final image in _selectedImages) {
          await memSvc.addPhotoMemory(
            capsuleId: capsuleId,
            userId: userId,
            imageFile: image,
            capsuleKey: capsuleKey,
          );
        }
      }

      if (mounted) {
        context.read<CapsuleProvider>().addCapsule(capsuleData);
      }

      HapticFeedback.mediumImpact();

      // ✅ Pop FIRST, then show snackbar on the parent screen's context
      navigator.pop();

      messenger.showSnackBar(SnackBar(
        content: const Row(
          children: [
            Text('🔒', style: TextStyle(fontSize: 18)),
            SizedBox(width: 10),
            Text('Capsule sealed!',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (mounted) _showSnack('Failed to seal capsule: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.cardDark2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onWillPop()) {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              if (await _onWillPop()) Navigator.pop(context);
            },
          ),
          title: const Text('New Capsule',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
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
                    _label('Choose an emoji'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _quickEmojis.length,
                              itemBuilder: (_, i) {
                                final e = _quickEmojis[i];
                                final selected = e == _emoji;
                                return GestureDetector(
                                  onTap: () => setState(() => _emoji = e),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(right: 10),
                                    width: 52, height: 52,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.white
                                          : AppTheme.cardDark2,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                        child: Text(e,
                                            style: const TextStyle(
                                                fontSize: 24))),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _showEmojiGrid,
                          child: Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark2,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                                child: Text('＋',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 20))),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _label('Capsule Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          _inputDeco('e.g. Summer 2026, Letter to future me'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text('Give it a name you\'ll remember.',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 12)),
                    const SizedBox(height: 20),

                    _label('Write a message (optional)'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 5,
                        minLines: 3,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15, height: 1.5),
                        decoration: const InputDecoration(
                          hintText:
                              'A note, memory, or letter to your future self...',
                          hintStyle: TextStyle(color: AppTheme.mutedText2),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

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
                                      ? AppTheme.mutedText2
                                      : Colors.white,
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
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12)),
                    const SizedBox(height: 28),

                    Row(
                      children: [
                        _label('Photos (optional)'),
                        const Spacer(),
                        GestureDetector(
                          onTap: _pickImages,
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
                                Text('Add Photos',
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
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.cardDark2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: Colors.white.withOpacity(0.2),
                                  size: 32),
                              const SizedBox(height: 8),
                              Text('Tap to add photos',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.25),
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Text('Tap a photo to set as cover',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 12)),
                      const SizedBox(height: 8),
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
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => setState(() => _coverIndex = i),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(_selectedImages[i],
                                    fit: BoxFit.cover),
                              ),
                              if (_coverIndex == i)
                                Positioned(
                                  top: 4, left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Cover',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              Positioned(
                                top: 4, right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _selectedImages.removeAt(i);
                                    if (_coverIndex == i) {
                                      _coverIndex =
                                          _selectedImages.isEmpty ? null : 0;
                                    } else if (_coverIndex != null &&
                                        _coverIndex! > i) {
                                      _coverIndex = _coverIndex! - 1;
                                    }
                                  }),
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
                      ),
                    ],

                    const SizedBox(height: 16),
                    Text(
                      '🔒 Everything is encrypted the moment you tap Seal it.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.35), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

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
                        : const Text('Seal it',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
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