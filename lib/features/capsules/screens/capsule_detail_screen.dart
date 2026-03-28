import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:boxed_app/core/services/encryption_service.dart';
import 'package:boxed_app/core/state/capsule_crypto_state.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/features/capsules/providers/capsule_provider.dart';
import 'package:boxed_app/features/capsules/services/capsule_service.dart';
import 'package:boxed_app/features/memories/screens/memory_feed_screen.dart';

class CapsuleDetailScreen extends StatefulWidget {
  final String capsuleId;
  const CapsuleDetailScreen({super.key, required this.capsuleId});

  @override
  State<CapsuleDetailScreen> createState() => _CapsuleDetailScreenState();
}

enum _Stage { loading, error, locked, unlockReady, revealed }

class _CapsuleDetailScreenState extends State<CapsuleDetailScreen> {
  _Stage _stage = _Stage.loading;
  String? _error;

  Map<String, dynamic>? _capsuleData;
  DateTime? _unlockDate;
  DateTime? _createdAt;
  Duration _remaining = Duration.zero;
  Timer? _timer;

  late ConfettiController _confettiController;
  final _capsuleService = CapsuleService();

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
    CapsuleCryptoState.clearKey(widget.capsuleId);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _stage = _Stage.loading);
    try {
      final provider = context.read<CapsuleProvider>();
      Map<String, dynamic>? data;

      try {
        data = provider.capsules
            .firstWhere((c) => c['capsuleId'] == widget.capsuleId);
      } catch (_) {
        data = null;
      }

      data ??= await _capsuleService.fetchCapsuleById(widget.capsuleId);

      if (data == null) {
        setState(() {
          _stage = _Stage.error;
          _error = 'Capsule not found.';
        });
        return;
      }

      _capsuleData = data;

      final encryptedKey = data['encryptedCapsuleKey'] as String;
      final masterKey = UserCryptoState.userMasterKey;
      final capsuleKey = await EncryptionService.decryptCapsuleKey(
        encryptedKey: encryptedKey,
        userMasterKey: masterKey,
      );
      CapsuleCryptoState.setKey(widget.capsuleId, capsuleKey);

      final unlockDate =
          DateTime.parse(data['unlockDate'] as String).toLocal();
      _unlockDate = unlockDate;

      if (data['createdAt'] != null) {
        _createdAt =
            DateTime.tryParse(data['createdAt'].toString())?.toLocal();
      }

      final now = DateTime.now();
      if (now.isBefore(unlockDate)) {
        _remaining = unlockDate.difference(now);
        _startTimer();
        setState(() => _stage = _Stage.locked);
      } else {
        final isRevealed = data['isRevealed'] == true;
        setState(() =>
            _stage = isRevealed ? _Stage.revealed : _Stage.unlockReady);
      }
    } catch (e) {
      setState(() {
        _stage = _Stage.error;
        _error = e.toString();
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_unlockDate == null) return;
      final now = DateTime.now();
      if (now.isAfter(_unlockDate!)) {
        _timer?.cancel();
        if (mounted) {
          setState(() {
            _stage = _Stage.unlockReady;
            _remaining = Duration.zero;
          });
        }
      } else {
        if (mounted) {
          setState(() => _remaining = _unlockDate!.difference(now));
        }
      }
    });
  }

  Future<void> _reveal() async {
    // ✅ Haptic feedback on reveal
    HapticFeedback.heavyImpact();
    await _capsuleService.markRevealed(widget.capsuleId);
    _confettiController.play();
    if (mounted) setState(() => _stage = _Stage.revealed);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete capsule?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete the capsule and all its memories.',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<CapsuleProvider>().deleteCapsule(widget.capsuleId);
    if (mounted) Navigator.pop(context);
  }

  void _share() {
    final title =
        (_capsuleData?['name'] ?? 'My Capsule').toString();
    final unlockStr = _unlockDate != null
        ? DateFormat('MMM d, yyyy').format(_unlockDate!)
        : '';
    Share.share(
      '📦 I just opened my Boxed capsule — "$title" — sealed on $unlockStr. Check out Boxed!',
    );
  }

  double _lockProgress() {
    if (_createdAt == null || _unlockDate == null) return 0.0;
    final total = _unlockDate!.difference(_createdAt!).inSeconds;
    if (total <= 0) return 1.0;
    final elapsed = DateTime.now().difference(_createdAt!).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String _timeWaited() {
    if (_createdAt == null || _unlockDate == null) return '';
    final days = _unlockDate!.difference(_createdAt!).inDays;
    if (days < 1) return 'Less than a day';
    if (days == 1) return '1 day';
    if (days < 30) return '$days days';
    if (days < 365) {
      final months = (days / 30).round();
      return '$months month${months > 1 ? 's' : ''}';
    }
    final years = (days / 365 * 10).round() / 10;
    return '$years year${years != 1.0 ? 's' : ''}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.loading:
        return const Scaffold(
          backgroundColor: Colors.black,
          body:
              Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      case _Stage.error:
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? 'Something went wrong',
                      style: const TextStyle(color: AppTheme.red),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: _load,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      case _Stage.locked:
        return _buildLocked();
      case _Stage.unlockReady:
        return _buildUnlockReady();
      case _Stage.revealed:
        return _buildRevealed();
    }
  }

  Widget _buildLocked() {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;
    final title =
        (_capsuleData?['name'] ?? 'Your Capsule').toString();
    final emoji = (_capsuleData?['emoji'] ?? '📦').toString();
    final unlockStr = _unlockDate != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(_unlockDate!)
        : '';
    final progress = _lockProgress();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _delete,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your memories are sealed inside. Almost time.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _timeTile(_pad(days), 'Days'),
                  const SizedBox(width: 10),
                  _timeTile(_pad(hours), 'Hours'),
                  const SizedBox(width: 10),
                  _timeTile(_pad(minutes), 'Min'),
                  const SizedBox(width: 10),
                  _timeTile(_pad(seconds), 'Sec'),
                ],
              ),
              const SizedBox(height: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Wait progress',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% done',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.blue.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (unlockStr.isNotEmpty)
                Text(
                  'Unlocks on $unlockStr',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              Text(
                '🔒 All memories are end-to-end encrypted.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.2), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeTile(String value, String label) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildUnlockReady() {
    final title =
        (_capsuleData?['name'] ?? 'Your Capsule').toString();
    final emoji = (_capsuleData?['emoji'] ?? '📦').toString();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 22),
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your memories are ready to be revealed.',
                style:
                    TextStyle(color: Colors.white.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _reveal,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Reveal Memories',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevealed() {
    final title =
        (_capsuleData?['name'] ?? 'Your Capsule').toString();
    final emoji = (_capsuleData?['emoji'] ?? '📦').toString();
    final desc = (_capsuleData?['description'] ?? '').toString();

    final sealedStr = _createdAt != null
        ? DateFormat('MMM d, yyyy').format(_createdAt!)
        : '';
    final openedStr = _unlockDate != null
        ? DateFormat('MMM d, yyyy').format(_unlockDate!)
        : '';
    final timeWaited = _timeWaited();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (sealedStr.isNotEmpty && openedStr.isNotEmpty) ...[
                    Text(
                      'Sealed $sealedStr  →  Opened $openedStr',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (openedStr.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '🔓 Opened on $openedStr',
                        style: TextStyle(
                            color: AppTheme.green.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  if (timeWaited.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Text('⏳',
                              style: TextStyle(fontSize: 24)),
                          const SizedBox(height: 6),
                          Text(
                            'You waited $timeWaited',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Worth the wait.',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        desc,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            height: 1.5,
                            fontSize: 14),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemoryFeedScreen(
                              capsuleId: widget.capsuleId),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('View Memories',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              gravity: 0.3,
              colors: const [
                Colors.white,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.pink,
              ],
            ),
          ),
        ],
      ),
    );
  }
}