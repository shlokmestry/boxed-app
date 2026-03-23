import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/providers/theme_provider.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/features/auth/services/auth_service.dart';
import 'package:boxed_app/features/capsules/providers/capsule_provider.dart';
import 'package:boxed_app/core/router/app_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _authService = AuthService();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      if (auth.user == null) return;
      final data = await _authService.getUserProfile(auth.user!.$id);
      _displayNameController.text = data?['displayName'] ?? '';
      _bioController.text = data?['bio'] ?? '';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      if (auth.user == null) return;
      await _authService.updateProfile(
        userId: auth.user!.$id,
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: AppTheme.cardDark2,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    context.read<CapsuleProvider>().clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
        context, AppRouter.login, (_) => false);
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark2,
        title: const Text('Delete account?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'This will permanently delete your account and all your capsules. This cannot be undone.',
            style: TextStyle(color: AppTheme.mutedText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        await _authService.deleteAccount(auth.user!.$id);
      }
      await auth.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, AppRouter.login, (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppTheme.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text('Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // PROFILE section
                _sectionLabel('PROFILE'),
                const SizedBox(height: 12),
                _card([
                  _inputTile(
                    label: 'Display Name',
                    controller: _displayNameController,
                    hint: 'Your name',
                  ),
                  const _Divider(),
                  _inputTile(
                    label: 'Bio',
                    controller: _bioController,
                    hint: 'A short bio',
                    maxLines: 3,
                  ),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _saving ? null : _save,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 28),

                // APPEARANCE section
                _sectionLabel('APPEARANCE'),
                const SizedBox(height: 12),
                _card([
                  _themeTile(
                    label: 'Dark Mode',
                    icon: Icons.dark_mode_outlined,
                    value: ThemeMode.dark,
                    groupValue: themeProvider.themeMode,
                    onChanged: (v) => themeProvider.setThemeMode(v!),
                  ),
                  const _Divider(),
                  _themeTile(
                    label: 'Light Mode',
                    icon: Icons.light_mode_outlined,
                    value: ThemeMode.light,
                    groupValue: themeProvider.themeMode,
                    onChanged: (v) => themeProvider.setThemeMode(v!),
                  ),
                  const _Divider(),
                  _themeTile(
                    label: 'System Default',
                    icon: Icons.phone_android_outlined,
                    value: ThemeMode.system,
                    groupValue: themeProvider.themeMode,
                    onChanged: (v) => themeProvider.setThemeMode(v!),
                  ),
                ]),
                const SizedBox(height: 28),

                // ACCOUNT section
                _sectionLabel('ACCOUNT'),
                const SizedBox(height: 12),
                _card([
                  _actionTile(
                    label: 'Sign Out',
                    icon: Icons.logout,
                    onTap: _logout,
                  ),
                  const _Divider(),
                  _actionTile(
                    label: 'Delete Account',
                    icon: Icons.delete_forever_outlined,
                    onTap: _deleteAccount,
                    destructive: true,
                  ),
                ]),
                const SizedBox(height: 32),

                Center(
                  child: Text('Boxed v1.0.0',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 13)),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5));

  Widget _card(List<Widget> children) => Container(
      decoration: BoxDecoration(
          color: AppTheme.cardDark2,
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: children));

  Widget _inputTile({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppTheme.mutedText2),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeTile({
    required String label,
    required IconData icon,
    required ThemeMode value,
    required ThemeMode groupValue,
    required ValueChanged<ThemeMode?> onChanged,
  }) {
    return RadioListTile<ThemeMode>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: Colors.white,
      title: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _actionTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon,
                  color: destructive ? AppTheme.red : Colors.white,
                  size: 22),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      color: destructive ? AppTheme.red : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFF1A1A1A),
        indent: 16,
        endIndent: 16);
  }
}