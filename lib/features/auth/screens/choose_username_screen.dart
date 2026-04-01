import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/features/auth/services/auth_service.dart';
import 'package:boxed_app/core/router/app_router.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'dart:math';

class ChooseUsernameScreen extends StatefulWidget {
  const ChooseUsernameScreen({super.key});

  @override
  State<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends State<ChooseUsernameScreen> {
  final _controller = TextEditingController();
  final _authService = AuthService();
  final _storage = const FlutterSecureStorage();

  bool _checking = false;
  bool _isAvailable = false;
  bool _isSaving = false;
  String? _feedback;

  static const int _maxLength = 16;

  final _adjectives = [
    'Arctic', 'Astral', 'Atomic', 'Auburn', 'Azure', 'Barren', 'Blaze',
    'Bleak', 'Blinding', 'Blizzard', 'Blooming', 'Blurred', 'Boreal', 'Broken',
    'Bronze', 'Burning', 'Carved', 'Celestial', 'Charred', 'Chrome', 'Cinder',
    'Clouded', 'Cobalt', 'Collapsed', 'Comet', 'Cracked', 'Crescent', 'Crystal',
    'Cursed', 'Dawnlit', 'Dead', 'Decayed', 'Deep', 'Dented', 'Dim', 'Distant',
    'Drifting', 'Dusk', 'Dying', 'Eerie', 'Electric', 'Ember', 'Endless',
    'Ethereal', 'Exiled', 'Expired', 'Faded', 'Fallen', 'Fierce', 'Flicker',
    'Floating', 'Foggy', 'Forsaken', 'Fractured', 'Ghostly', 'Glacial', 'Glowing',
    'Granite', 'Grim', 'Haunted', 'Hazy', 'Hidden', 'Hollow', 'Hungry',
    'Icy', 'Idle', 'Infinite', 'Infrared', 'Ink', 'Inverted', 'Iron',
    'Jagged', 'Jade', 'Lost', 'Lucid', 'Magma', 'Melted', 'Midnight',
    'Molten', 'Mossy', 'Murky', 'Muted', 'Mythic', 'Nether', 'Numb',
    'Obsidian', 'Onyx', 'Opaque', 'Orbital', 'Pale', 'Parallel', 'Prism',
    'Radiant', 'Ruined', 'Scattered', 'Sealed', 'Shattered', 'Shifting', 'Silver',
  ];

  final _nouns = [
    'Abyss', 'Anvil', 'Apex', 'Archive', 'Arrow', 'Ash', 'Atlas',
    'Atom', 'Beacon', 'Blade', 'Blaze', 'Bloom', 'Bolt', 'Bone',
    'Breach', 'Bunker', 'Byte', 'Cache', 'Cage', 'Canyon', 'Carbon',
    'Cascade', 'Cave', 'Chain', 'Chamber', 'Chasm', 'Circuit', 'Citadel',
    'Claw', 'Clone', 'Cloud', 'Cluster', 'Code', 'Colony', 'Core',
    'Crater', 'Crest', 'Crew', 'Crown', 'Crypt', 'Cube', 'Current',
    'Dagger', 'Data', 'Dawn', 'Debris', 'Deck', 'Delta', 'Den',
    'Depth', 'Desert', 'Dome', 'Drift', 'Drop', 'Dune', 'Dust',
    'Echo', 'Edge', 'Epoch', 'Expanse', 'Eye', 'Field', 'Flare',
    'Flash', 'Flint', 'Flux', 'Forge', 'Fork', 'Fracture', 'Frame',
    'Frost', 'Fuel', 'Fuse', 'Gate', 'Glyph', 'Grid', 'Grove',
    'Guard', 'Guild', 'Halo', 'Harbor', 'Hatch', 'Hawk', 'Helm',
    'Horn', 'Hull', 'Hunter', 'Husk', 'Index', 'Isle', 'Junction',
    'Keep', 'Key', 'Lance', 'Layer', 'Ledge', 'Legion', 'Lens',
  ];

  final _blocklist = [
    'admin', 'fuck', 'shit', 'bitch', 'asshole', 'cunt', 'nigger', 'nigga',
    'faggot', 'retard', 'whore', 'slut', 'dick', 'cock', 'pussy',
  ];

  @override
  void initState() {
    super.initState();
    _suggest();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _suggest() {
    final rand = Random();
    final username =
        '${_adjectives[rand.nextInt(_adjectives.length)]}'
        '${_nouns[rand.nextInt(_nouns.length)]}'
        '${rand.nextInt(9999)}';
    _controller.text = username;
    _check(username);
  }

  String? _validate(String trimmed) {
    if (trimmed.length < 3) return 'Too short. At least 3 characters.';
    if (trimmed.length > _maxLength)
      return "Usernames can't be longer than $_maxLength characters.";
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed))
      return 'Letters, numbers, and underscores only.';
    if (trimmed.startsWith('_') || trimmed.endsWith('_'))
      return "Can't start or end with an underscore.";
    if (trimmed.contains('__')) return 'No double underscores.';
    final lower = trimmed.toLowerCase();
    for (final word in _blocklist) {
      if (lower.contains(word)) return "That username isn't allowed.";
    }
    return null;
  }

  Future<void> _check(String username) async {
    final trimmed = username.trim();
    final validationError = _validate(trimmed);

    if (validationError != null) {
      setState(() {
        _checking = false;
        _isAvailable = false;
        _feedback = validationError;
      });
      return;
    }

    setState(() {
      _checking = true;
      _isAvailable = false;
      _feedback = null;
    });

    final available = await _authService.isUsernameAvailable(trimmed);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _isAvailable = available;
      _feedback = available
          ? 'All yours. No one else has it.'
          : 'Already claimed. Try something else.';
    });
  }

  Future<void> _confirm() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null || !_isAvailable) return;

    setState(() => _isSaving = true);

    try {
      await _authService.setUsername(
        userId: auth.user!.$id,
        username: _controller.text.trim(),
      );
      if (!mounted) return;

      await _storage.delete(key: 'welcome_seen');

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.home);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _feedback = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLength = _controller.text.trim().length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text('📦', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 24),
              const Text(
                'Pick your username',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Claim your corner of Boxed',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 40),

              // Field + character counter
              Stack(
                clipBehavior: Clip.none,
                children: [
                  TextField(
                    controller: _controller,
                    onChanged: _check,
                    enabled: !_isSaving,
                    maxLength: _maxLength,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9_]')),
                    ],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixText: '@',
                      prefixStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: AppTheme.cardDark2,
                      hintText: 'username',
                      hintStyle:
                          const TextStyle(color: AppTheme.mutedText2),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded,
                                color: AppTheme.mutedText2),
                            onPressed: _isSaving ? null : _suggest,
                            tooltip: 'Suggest another',
                          ),
                          if (_checking)
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else if (_isAvailable)
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.check_circle,
                                  color: AppTheme.green),
                            ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: -20,
                    child: Text(
                      '$currentLength/$_maxLength',
                      style: TextStyle(
                        color: currentLength > _maxLength
                            ? AppTheme.red
                            : Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),

              if (_feedback != null) ...[
                const SizedBox(height: 12),
                Text(
                  _feedback!,
                  style: TextStyle(
                    color: _isAvailable ? AppTheme.green : AppTheme.red,
                    fontSize: 13,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ✅ Fix: use unique keys that change based on state
              // so AnimatedSwitcher never sees duplicate keys
              SizedBox(
                width: double.infinity,
                height: 52,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isAvailable && !_isSaving
                      ? ElevatedButton(
                          key: const ValueKey('btn_active'),
                          onPressed: _confirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Claim it',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                          ),
                        )
                      : OutlinedButton(
                          key: const ValueKey('btn_inactive'),
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Claim it',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
                        ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}