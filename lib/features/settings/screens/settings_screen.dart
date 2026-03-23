import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/providers/theme_provider.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/features/auth/services/auth_service.dart';
import 'package:boxed_app/features/capsules/providers/capsule_provider.dart';
import 'package:boxed_app/core/router/app_router.dart';
import 'package:boxed_app/features/settings/screens/edit_profile_screen.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
     backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text('Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [

          // ACCOUNT
          _sectionLabel('ACCOUNT'),
          const SizedBox(height: 10),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.person_outline,
              label: 'Edit Profile',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EditProfileScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // APPEARANCE
          _sectionLabel('APPEARANCE'),
          const SizedBox(height: 10),
          _SettingsCard(children: [
            _ThemeOptionTile(
              label: 'Dark Mode',
              icon: Icons.dark_mode_outlined,
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
            ),
            const _Divider(),
            _ThemeOptionTile(
              label: 'Light Mode',
              icon: Icons.light_mode_outlined,
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              onTap: () => themeProvider.setThemeMode(ThemeMode.light),
            ),
          ]),
          const SizedBox(height: 24),

          // MORE
          _sectionLabel('MORE'),
          const SizedBox(height: 10),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.share_outlined,
              label: 'Share Boxed',
              onTap: () => Share.share(
                'Check out Boxed — a time capsule app to seal memories and open them later! 📦',
              ),
            ),
            const _Divider(),
            _SettingsTile(
              icon: Icons.info_outline,
              label: 'About',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Boxed',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Boxed. All rights reserved.',
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Seal memories. Open later.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // ACCOUNT ACTIONS
          _sectionLabel('ACCOUNT ACTIONS'),
          const SizedBox(height: 10),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              onTap: () => _confirmSignOut(context),
            ),
            const _Divider(),
            _SettingsTile(
              icon: Icons.delete_forever_outlined,
              label: 'Delete Account',
              destructive: true,
              onTap: () => _confirmDeleteAccount(context),
            ),
          ]),
          const SizedBox(height: 32),

          Center(
            child: Text(
              'Boxed v1.0.0',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.2), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      );

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('You can always log back in.',
            style: TextStyle(color: Colors.white.withOpacity(0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    context.read<CapsuleProvider>().clear();
    Navigator.pushNamedAndRemoveUntil(
        context, AppRouter.login, (_) => false);
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete account?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
            'This will permanently delete your account and all your capsules. This cannot be undone.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        await AuthService().deleteAccount(auth.user!.$id);
      }
      await auth.logout();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, AppRouter.login, (_) => false);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.red),
      );
    }
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,

        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: destructive
                      ? AppTheme.red.withOpacity(0.12)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon,
                    color: destructive ? AppTheme.red : Colors.white,
                    size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: destructive ? AppTheme.red : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!destructive)
                Icon(Icons.chevron_right,
                    color: Colors.white.withOpacity(0.25), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final ThemeMode value;
  final ThemeMode groupValue;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.12)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon,
                    color: selected ? Colors.white : Colors.white54,
                    size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontSize: 15,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      color: Colors.black, size: 13),
                )
              else
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5),
                  ),
                ),
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
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withOpacity(0.05),
      indent: 64,
      endIndent: 16,
    );
  }
}