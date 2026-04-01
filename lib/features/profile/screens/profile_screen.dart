import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:boxed_app/core/router/app_router.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/features/auth/services/auth_service.dart';
import 'package:boxed_app/features/capsules/providers/capsule_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _loading = true;
  final _authService = AuthService();

  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  static const _avatarEmojis = [
    '😊', '😎', '🤩', '🥰', '😄', '🤓', '😏', '🥸',
    '🧑', '👩', '👨', '🧒', '👧', '👦', '🧔', '👱',
    '🦊', '🐺', '🦁', '🐻', '🐼', '🐨', '🦄', '🐸',
    '🌟', '⚡', '🔥', '🌊', '🌙', '☀️', '🌈', '❄️',
    '🎭', '🎸', '🎨', '📸', '✈️', '🚀', '⚽', '🏄',
  ];

  String _selectedAvatarEmoji = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      if (auth.user == null) return;
      await context.read<CapsuleProvider>().loadCapsules(auth.user!.$id);
      final data = await _authService.getUserProfile(auth.user!.$id);
      if (mounted) {
        setState(() {
          _profileData = data;
          _selectedAvatarEmoji = (data?['avatarEmoji'] as String? ?? '').trim();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showEditProfile() {
    final displayName = _profileData?['displayName'] as String? ?? '';
    final bio = _profileData?['bio'] as String? ?? '';
    _displayNameController.text = displayName;
    _bioController.text = bio;
    String sheetAvatar = _selectedAvatarEmoji;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24,
              MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 20),
                const Text('Edit Profile',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                Text('Avatar', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _avatarEmojis.length,
                    itemBuilder: (_, i) {
                      final e = _avatarEmojis[i];
                      final selected = sheetAvatar == e;
                      return GestureDetector(
                        onTap: () => setSheetState(() => sheetAvatar = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : AppTheme.cardDark2,
                            borderRadius: BorderRadius.circular(12),
                            border: selected ? null : Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text('Username', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppTheme.cardDark2, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Text('@${_profileData?['username'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 15)),
                    const Spacer(),
                    Icon(Icons.lock_outline, color: Colors.white.withOpacity(0.2), size: 14),
                  ]),
                ),
                const SizedBox(height: 4),
                Text('Username cannot be changed', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11)),
                const SizedBox(height: 16),
                Text('Display Name', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _displayNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    hintStyle: const TextStyle(color: AppTheme.mutedText2),
                    filled: true, fillColor: AppTheme.cardDark2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Bio', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioController,
                  maxLines: 3, maxLength: 120,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'A little about you...',
                    hintStyle: const TextStyle(color: AppTheme.mutedText2),
                    filled: true, fillColor: AppTheme.cardDark2,
                    counterStyle: const TextStyle(color: AppTheme.mutedText2),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final auth = context.read<AuthProvider>();
                      try {
                        await _authService.updateUserProfile(
                          userId: auth.user!.$id,
                          displayName: _displayNameController.text.trim(),
                          bio: _bioController.text.trim(),
                          avatarEmoji: sheetAvatar,
                        );
                        if (!mounted) return;
                        setState(() => _selectedAvatarEmoji = sheetAvatar);
                        Navigator.pop(ctx);
                        _load();
                      } catch (_) {
                        if (!mounted) return;
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _memberSince() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return '';
    try {
      final reg = DateTime.parse(user.registration.toString());
      return 'Member since ${DateFormat('MMMM yyyy').format(reg)}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _handleSignOut() async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text("You'll need to sign back in.", style: TextStyle(color: Colors.white.withOpacity(0.6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Sign out', style: TextStyle(color: AppTheme.red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    context.read<CapsuleProvider>().clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRouter.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final capsuleProvider = context.watch<CapsuleProvider>();
    final capsules = capsuleProvider.capsules;

    final username = _profileData?['username'] as String? ?? '';
    final displayName = _profileData?['displayName'] as String? ?? '';
    final bio = _profileData?['bio'] as String? ?? '';
    final email = auth.user?.email ?? '';
    final memberSince = _memberSince();
    final avatarEmoji = _selectedAvatarEmoji;

    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase()
        : email.isNotEmpty ? email[0].toUpperCase() : 'U';

    Map<String, dynamic>? recentCapsule;
    if (capsules.isNotEmpty) {
      final sorted = [...capsules];
      sorted.sort((a, b) {
        final aDate = DateTime.tryParse(a['\$createdAt'] ?? a['createdAt'] ?? '') ?? DateTime(0);
        final bDate = DateTime.tryParse(b['\$createdAt'] ?? b['createdAt'] ?? '') ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
      recentCapsule = sorted.first;
    }

    final totalCapsules = capsules.length;
    final unlockedCount = capsules.where((c) {
      final u = DateTime.tryParse(c['unlockDate'] ?? '');
      return u != null && DateTime.now().isAfter(u);
    }).length;
    final lockedCount = totalCapsules - unlockedCount;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: bio.isNotEmpty ? 320 : 290,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            // ✅ Only edit button — settings icon removed
            actions: const [],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1C1C1C), Color(0xFF0A0A0A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(top: -40, right: -40,
                    child: Container(width: 200, height: 200,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.02)))),
                  Positioned(bottom: -20, left: -20,
                    child: Container(width: 150, height: 150,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.02)))),
                  Positioned(
                    bottom: 28, left: 0, right: 0,
                    child: _loading ? _headerSkeleton() : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _showEditProfile,
                          child: Stack(children: [
                            Container(
                              width: 84, height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: avatarEmoji.isNotEmpty ? AppTheme.cardDark2 : Colors.white,
                                border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
                              ),
                              child: Center(
                                child: avatarEmoji.isNotEmpty
                                    ? Text(avatarEmoji, style: const TextStyle(fontSize: 38))
                                    : Text(initials, style: const TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.w700)),
                              ),
                            ),
                            Positioned(bottom: 0, right: 0,
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF0A0A0A), width: 2),
                                ),
                                child: const Icon(Icons.edit, size: 12, color: Colors.black),
                              )),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        Text(displayName.isNotEmpty ? displayName : 'Boxed User',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                        const SizedBox(height: 6),
                        if (username.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                            child: Text('@$username', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                        if (memberSince.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(memberSince, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                        ],
                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(bio,
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.4),
                                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: _loading ? _bodySkeleton() : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(children: [
                      Expanded(child: _statItem(value: totalCapsules.toString(), label: 'Capsules', icon: '📦')),
                      Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08)),
                      Expanded(child: _statItem(value: unlockedCount.toString(), label: 'Unlocked', icon: '🔓')),
                      Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08)),
                      Expanded(child: _statItem(value: lockedCount.toString(), label: 'Locked', icon: '🔒')),
                    ]),
                  ),
                  const SizedBox(height: 28),

                  if (recentCapsule != null) ...[
                    Text('Most Recent', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _RecentCapsuleCard(data: recentCapsule),
                    const SizedBox(height: 28),
                  ],

                  // ✅ Settings navigates to settings screen, Sign out works correctly
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(children: [
                      _settingsRow(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        onTap: () async {
                          await Navigator.pushNamed(context, AppRouter.settings);
                          _load();
                        },
                      ),
                      Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                      _settingsRow(
                        icon: Icons.logout,
                        label: 'Sign out',
                        color: AppTheme.red,
                        onTap: _handleSignOut,
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsRow({required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    final c = color ?? Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(children: [
            Icon(icon, color: c.withOpacity(0.7), size: 20),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2), size: 18),
          ]),
        ),
      ),
    );
  }

  Widget _headerSkeleton() => Column(children: [
    Container(width: 84, height: 84, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08))),
    const SizedBox(height: 14),
    Container(width: 140, height: 18, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8))),
    const SizedBox(height: 8),
    Container(width: 90, height: 12, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6))),
  ]);

  Widget _bodySkeleton() => Container(height: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)));

  Widget _statItem({required String value, required String label, required String icon}) => Column(children: [
    Text(icon, style: const TextStyle(fontSize: 20)),
    const SizedBox(height: 8),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12, fontWeight: FontWeight.w500)),
  ]);
}

class _RecentCapsuleCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RecentCapsuleCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Untitled').toString();
    final emoji = (data['emoji'] ?? '📦').toString();
    final unlockDate = DateTime.tryParse(data['unlockDate'] ?? '');
    final isUnlocked = unlockDate != null && DateTime.now().isAfter(unlockDate);
    final unlockStr = unlockDate != null ? DateFormat('MMM d, yyyy').format(unlockDate.toLocal()) : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: isUnlocked ? AppTheme.green.withOpacity(0.6) : AppTheme.blue.withOpacity(0.6), width: 3)),
      ),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: AppTheme.cardDark2, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(unlockStr, style: const TextStyle(color: AppTheme.mutedText2, fontSize: 13)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isUnlocked ? AppTheme.green.withOpacity(0.15) : AppTheme.blue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(isUnlocked ? 'Unlocked' : 'Locked',
              style: TextStyle(color: isUnlocked ? AppTheme.green : AppTheme.blue, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}