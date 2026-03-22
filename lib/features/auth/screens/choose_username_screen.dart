import 'package:flutter/material.dart';
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
  bool _checking = false;
  bool _isAvailable = false;
  bool _isSaving = false;
  String? _feedback;

  final _adjectives = ['Happy','Cosmic','Brave','Chill','Swift','Mystic','Bold','Wild'];
  final _nouns = ['Penguin','Wizard','Fox','Capsule','Pixel','Dragon','Tiger','Wolf'];

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
        '${_adjectives[rand.nextInt(_adjectives.length)]}${_nouns[rand.nextInt(_nouns.length)]}${rand.nextInt(9999)}';
    _controller.text = username;
    _check(username);
  }

  Future<void> _check(String username) async {
    setState(() { _checking = true; _isAvailable = false; _feedback = null; });
    final trimmed = username.trim();
    if (trimmed.length < 3) {
      setState(() { _checking = false; _feedback = 'At least 3 characters'; });
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      setState(() { _checking = false; _feedback = 'Letters, numbers and underscores only'; });
      return;
    }
    final available = await _authService.isUsernameAvailable(trimmed);
    setState(() {
      _checking = false;
      _isAvailable = available;
      _feedback = available ? "That one's all yours!" : 'Username taken. Try another.';
    });
  }

  Future<void> _confirm() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null || !_isAvailable) return;
    setState(() => _isSaving = true);
    await _authService.setUsername(userId: auth.user!.$id, username: _controller.text.trim());
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, automaticallyImplyLeading: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text('👤', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 24),
              const Text('Pick your username',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('How friends will find you',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15)),
              const SizedBox(height: 40),
              TextField(
                controller: _controller,
                onChanged: _check,
                enabled: !_isSaving,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixText: '@',
                  prefixStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: AppTheme.cardDark2,
                  hintText: 'username',
                  hintStyle: const TextStyle(color: AppTheme.mutedText2),
                  suffixIcon: _checking
                    ? const Padding(padding: EdgeInsets.all(12),
                        child: SizedBox(width:20,height:20,
                          child: CircularProgressIndicator(strokeWidth:2,color:Colors.white)))
                    : _isAvailable
                      ? const Icon(Icons.check_circle, color: AppTheme.green)
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              if (_feedback != null) ...[
                const SizedBox(height: 12),
                Text(_feedback!,
                  style: TextStyle(color: _isAvailable ? AppTheme.green : AppTheme.red, fontSize: 13)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 52,
                child: OutlinedButton(
                  onPressed: (_isSaving) ? null : (_isAvailable ? _confirm : _suggest),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                    ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                    : Text(_isAvailable ? 'Continue' : 'Suggest New',
                        style: const TextStyle(fontSize:16,fontWeight:FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}