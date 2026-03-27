import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/features/auth/services/auth_service.dart';
import 'package:boxed_app/features/capsules/providers/capsule_provider.dart';
import 'package:boxed_app/core/router/app_router.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
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
              icon: Icons.lock_outline,
              label: 'Change Password',
              onTap: () => Navigator.pushNamed(context, AppRouter.changePassword),
            ),
          ]),
          const SizedBox(height: 24),

          // MORE
          _sectionLabel('MORE'),
          const SizedBox(height: 10),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.person_add_outlined,
              label: 'Invite Friends',
              onTap: () => Share.share(
                'Hey! I\'ve been using Boxed — a time capsule app to seal memories and open them later. Check it out! 📦',
              ),
            ),
            const _Divider(),
            _SettingsTile(
              icon: Icons.info_outline,
              label: 'About Boxed',
              onTap: () => _showAboutSheet(context),
            ),
          ]),
          const SizedBox(height: 24),

          // DANGER ZONE
          _sectionLabel('DANGER ZONE'),
          const SizedBox(height: 10),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              muted: true,
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

          // Version — tappable to copy
          Center(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(
                    const ClipboardData(text: 'Boxed v$_appVersion'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('Version copied to clipboard',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ],
                    ),
                    backgroundColor: const Color(0xFF1A1A1A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text(
                'Boxed v$_appVersion',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.2), fontSize: 12),
              ),
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

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('📦', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text('Boxed',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'v$_appVersion',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Text(
              'Seal memories. Open later.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Boxed lets you create digital time capsules — lock in photos, notes, and moments, then rediscover them on a date you choose.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Made with ❤️ in Dublin.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '© 2026 Boxed. All rights reserved.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.2), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

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
        // ✅ Border removed
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
  final bool muted;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    // Destructive = red, muted = grey, normal = white
    final Color labelColor = destructive
        ? AppTheme.red
        : muted
            ? Colors.white54
            : Colors.white;

    final Color iconColor = destructive
        ? AppTheme.red
        : muted
            ? Colors.white38
            : Colors.white;

    final Color iconBg = destructive
        ? AppTheme.red.withOpacity(0.12)
        : Colors.white.withOpacity(0.06);

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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!destructive)
                Icon(Icons.chevron_right,
                    color: Colors.white.withOpacity(0.2), size: 20),
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