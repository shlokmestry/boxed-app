import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:boxed_app/core/router/app_router.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/features/auth/services/auth_service.dart';
import 'package:boxed_app/features/capsules/providers/capsule_provider.dart';
import 'package:boxed_app/features/capsules/screens/collaborate_contribute_screen.dart';
import 'package:boxed_app/features/capsules/services/capsule_service.dart';
import 'package:boxed_app/features/capsules/services/invite_service.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';

enum CapsuleFilter { all, upcoming, unlocked }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final _inviteService = InviteService();
  final _capsuleService = CapsuleService();

  String _query = '';
  CapsuleFilter _filter = CapsuleFilter.all;
  String _displayName = '';

  List<Map<String, dynamic>> _pendingInvites = [];
  bool _loadingInvites = false;
  List<Map<String, dynamic>> _collaboratorCapsules = [];
  List<Map<String, dynamic>> _pendingCapsules = [];
  List<Map<String, dynamic>> _declinedInvites = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _load();
      _loadDisplayName();
      _loadInvites();
      await _maybeShowWelcome();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      context.read<CapsuleProvider>().loadCapsules(auth.user!.$id);
      _loadCollaboratorCapsules(auth.user!.$id);
      _loadPendingCapsules(auth.user!.$id);
      _loadDeclinedInvites(auth.user!.$id);
    }
  }

  Future<void> _loadCollaboratorCapsules(String userId) async {
    try {
      final capsules = await _capsuleService.fetchCollaboratorCapsules(userId);
      if (mounted) setState(() => _collaboratorCapsules = capsules);
    } catch (_) {}
  }

  Future<void> _loadPendingCapsules(String userId) async {
    try {
      final capsules = await _capsuleService.fetchPendingCapsules(userId);
      if (mounted) setState(() => _pendingCapsules = capsules);
    } catch (_) {}
  }

  Future<void> _loadDeclinedInvites(String userId) async {
    try {
      final invites =
          await _inviteService.fetchDeclinedInvitesForCreator(userId);
      final authService = AuthService();
      final enriched = <Map<String, dynamic>>[];
      for (final invite in invites) {
        final toUserId = invite['toUserId'] as String? ?? '';
        final profile = await authService.getUserProfile(toUserId);
        final username = profile?['username'] as String? ?? '';
        enriched.add({...invite, 'declinedUsername': username});
      }
      if (mounted) setState(() => _declinedInvites = enriched);
    } catch (_) {}
  }

  Future<void> _loadInvites() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    setState(() => _loadingInvites = true);
    try {
      final invites =
          await _inviteService.fetchPendingInvites(auth.user!.$id);
      final authService = AuthService();
      final enriched = <Map<String, dynamic>>[];
      for (final invite in invites) {
        final fromUserId = invite['fromUserId'] as String? ?? '';
        final profile = await authService.getUserProfile(fromUserId);
        final username = profile?['username'] as String? ?? '';
        enriched.add({...invite, 'fromUsername': username});
      }
      if (mounted) setState(() => _pendingInvites = enriched);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingInvites = false);
    }
  }

  Future<void> _loadDisplayName() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    try {
      final data = await AuthService().getUserProfile(auth.user!.$id);
      final username = (data?['username'] as String? ?? '').trim();
      final display = (data?['displayName'] as String? ?? '').trim();
      if (mounted) {
        setState(
            () => _displayName = username.isNotEmpty ? username : display);
      }
    } catch (_) {}
  }

  Future<void> _maybeShowWelcome() async {
    final seen = await _storage.read(key: 'welcome_seen');
    if (seen == 'true' || !mounted) return;
    await _storage.write(key: 'welcome_seen', value: 'true');
    if (!mounted) return;
    _showWelcomeSheet();
  }

  void _showWelcomeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _WelcomeSheet(),
    ).then((_) async {
      if (!mounted) return;
      await Navigator.pushNamed(context, AppRouter.createCapsule);
      _load();
    });
  }

  Future<void> _acceptInvite(Map<String, dynamic> invite) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user!.$id;
    final inviteId = invite['inviteId'] as String;
    final capsuleId = invite['capsuleId'] as String;

    final capsuleData = await _capsuleService.fetchCapsuleById(capsuleId);
    if (capsuleData == null || !mounted) return;

    setState(() => _pendingInvites =
        _pendingInvites.where((i) => i['inviteId'] != inviteId).toList());

    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CollaborateContributeScreen(
          invite: invite,
          capsuleData: capsuleData,
        ),
      ),
    );

    if (accepted == true) {
      await _loadCollaboratorCapsules(userId);
      await _loadPendingCapsules(userId);
    } else {
      await _loadInvites();
    }
  }

  Future<void> _declineInvite(Map<String, dynamic> invite) async {
    final inviteId = invite['inviteId'] as String;
    final capsuleId = invite['capsuleId'] as String;

    setState(() => _pendingInvites =
        _pendingInvites.where((i) => i['inviteId'] != inviteId).toList());

    await _inviteService.declineInvite(inviteId);

    try {
      final capsuleData = await _capsuleService.fetchCapsuleById(capsuleId);
      if (capsuleData != null) {
        final pendingCount =
            (capsuleData['pendingInviteCount'] as num?)?.toInt() ?? 0;
        final collaboratorIds = List<String>.from(
            capsuleData['collaboratorIds'] as List? ?? []);

        if (pendingCount <= 1 && collaboratorIds.isEmpty) {
          await _capsuleService.deleteCapsule(capsuleId);
        } else {
          await _capsuleService.decrementPendingInviteCount(capsuleId);
          final allDone =
              await _inviteService.allInvitesResponded(capsuleId);
          if (allDone) {
            await _capsuleService.lockCapsule(capsuleId);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _dismissDeclined(Map<String, dynamic> invite) async {
    final inviteId = invite['inviteId'] as String;
    setState(() => _declinedInvites =
        _declinedInvites.where((i) => i['inviteId'] != inviteId).toList());
    await _inviteService.markDeclinedSeen(inviteId);
  }

  Future<void> _refresh() async {
    _load();
    _loadInvites();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Capsules refreshed',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> all) {
    var list = all.where((c) => c['status'] != 'pending').toList();
    if (_query.isNotEmpty) {
      list = list.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final desc = (c['description'] ?? '').toString().toLowerCase();
        return name.contains(_query) || desc.contains(_query);
      }).toList();
    }
    switch (_filter) {
      case CapsuleFilter.upcoming:
        list = list.where((c) {
          final unlock = DateTime.tryParse(c['unlockDate'] ?? '');
          return unlock != null && DateTime.now().isBefore(unlock);
        }).toList();
        break;
      case CapsuleFilter.unlocked:
        list = list.where((c) {
          final unlock = DateTime.tryParse(c['unlockDate'] ?? '');
          return unlock != null && DateTime.now().isAfter(unlock);
        }).toList();
        break;
      case CapsuleFilter.all:
        break;
    }
    return list;
  }

  Map<String, dynamic>? _nextUnlock(List<Map<String, dynamic>> capsules) {
    final now = DateTime.now();
    final upcoming = capsules.where((c) {
      final unlock = DateTime.tryParse(c['unlockDate'] ?? '');
      return unlock != null && unlock.isAfter(now);
    }).toList();
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) {
      final aDate = DateTime.parse(a['unlockDate']);
      final bDate = DateTime.parse(b['unlockDate']);
      return aDate.compareTo(bDate);
    });
    return upcoming.first;
  }

  String _nextUnlockLabel(DateTime unlock) {
    final diff = unlock.difference(DateTime.now());
    if (diff.inDays >= 1)
      return '⏳ Next unlock in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    if (diff.inHours >= 1)
      return '⏳ Next unlock in ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
    return '⏳ Next unlock in ${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'}';
  }

  Future<void> _confirmDelete(
      BuildContext context, String capsuleId, String name) async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete capsule?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          '"$name" will be permanently deleted. This cannot be undone.',
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
            child: Text('Delete', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.read<CapsuleProvider>().deleteCapsule(capsuleId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final capsuleProvider = context.watch<CapsuleProvider>();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final greeting = _displayName.isNotEmpty
        ? _displayName
        : (auth.user?.email?.split('@').first ?? 'there');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        title: Text('Hey $greeting 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            )),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRouter.profile),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.cardDark2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  (auth.user?.email ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: GestureDetector(
        onTap: () async {
          HapticFeedback.lightImpact();
          await Navigator.pushNamed(context, AppRouter.createCapsule);
          _load();
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.black, size: 28),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          children: [
            // ── Search bar (fixed, never scrolls) ─────────────
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.cardDark2,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search,
                      color: AppTheme.mutedText2, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Search capsules...',
                        hintStyle: TextStyle(color: AppTheme.mutedText2),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchController.clear(),
                      child: const Icon(Icons.close,
                          color: AppTheme.mutedText2, size: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Filter chips (fixed, never scrolls) ───────────
            Row(
              children: CapsuleFilter.values.map((f) {
                final selected = _filter == f;
                final label = f == CapsuleFilter.all
                    ? 'All'
                    : f == CapsuleFilter.upcoming
                        ? 'Upcoming'
                        : 'Unlocked';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : AppTheme.cardDark2,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(label,
                          style: TextStyle(
                            color: selected
                                ? Colors.black
                                : AppTheme.mutedText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Everything else scrolls ────────────────────────
            Expanded(child: _buildBody(capsuleProvider, bottomPad)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CapsuleProvider provider, double bottomPad) {
    switch (provider.state) {
      case CapsuleLoadState.loading:
        return ListView.builder(
          padding: EdgeInsets.only(bottom: bottomPad + 80),
          itemCount: 5,
          itemBuilder: (_, __) => const _ShimmerCard(),
        );

      case CapsuleLoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.error ?? 'Something went wrong',
                  style: const TextStyle(color: AppTheme.red),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _load,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        );

      case CapsuleLoadState.empty:
      case CapsuleLoadState.idle:
        if (_collaboratorCapsules.isNotEmpty ||
            _pendingCapsules.isNotEmpty ||
            _pendingInvites.isNotEmpty ||
            _declinedInvites.isNotEmpty) {
          return _buildList([], bottomPad);
        }
        return _EmptyState(
          filter: _filter,
          onCreateTap: () async {
            HapticFeedback.lightImpact();
            await Navigator.pushNamed(context, AppRouter.createCapsule);
            _load();
          },
        );

      case CapsuleLoadState.loaded:
        final filtered = _filtered(provider.capsules);
        if (filtered.isEmpty &&
            _collaboratorCapsules.isEmpty &&
            _pendingCapsules.isEmpty &&
            _pendingInvites.isEmpty &&
            _declinedInvites.isEmpty) {
          return _EmptyState(
            filter: _filter,
            onCreateTap: () async {
              HapticFeedback.lightImpact();
              await Navigator.pushNamed(
                  context, AppRouter.createCapsule);
              _load();
            },
          );
        }
        return _buildList(filtered, bottomPad);
    }
  }

  Widget _buildList(
      List<Map<String, dynamic>> ownCapsules, double bottomPad) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: Colors.white,
      backgroundColor: AppTheme.cardDark2,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomPad + 80),
        children: [
          // ── Banners scroll with the list — no more overflow ──

          // Next unlock banner
          Builder(builder: (_) {
            if (ownCapsules.isEmpty) return const SizedBox.shrink();
            final now = DateTime.now();
            final upcoming = ownCapsules.where((c) {
              final unlock = DateTime.tryParse(c['unlockDate'] ?? '');
              return unlock != null && unlock.isAfter(now);
            }).toList();
            if (upcoming.isEmpty) return const SizedBox.shrink();
            upcoming.sort((a, b) => DateTime.parse(a['unlockDate'])
                .compareTo(DateTime.parse(b['unlockDate'])));
            final unlockDate =
                DateTime.parse(upcoming.first['unlockDate']);
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.blue.withOpacity(0.25)),
              ),
              child: Text(_nextUnlockLabel(unlockDate),
                  style: TextStyle(
                    color: AppTheme.blue.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  )),
            );
          }),

          // Declined notifications
          ..._declinedInvites.map((invite) => _DeclinedBanner(
                invite: invite,
                onDismiss: () => _dismissDeclined(invite),
              )),

          // Pending invite banners
          ..._pendingInvites.map((invite) => _InviteBanner(
                invite: invite,
                onAccept: () => _acceptInvite(invite),
                onDecline: () => _declineInvite(invite),
              )),

          // ── Pending capsules (waiting for others) ────────────
          if (_pendingCapsules.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                      child: Divider(
                          color: Colors.white.withOpacity(0.08))),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('waiting on others',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        )),
                  ),
                  Expanded(
                      child: Divider(
                          color: Colors.white.withOpacity(0.08))),
                ],
              ),
            ),
            ..._pendingCapsules.map((c) => _PendingCapsuleCard(
                  data: c,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRouter.capsuleDetail,
                    arguments: c['capsuleId'] as String,
                  ),
                )),
            const SizedBox(height: 8),
          ],

          // ── Own capsules ──────────────────────────────────────
          ...ownCapsules.map((c) => _CapsuleCard(
                data: c,
                isCollaborator: false,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRouter.capsuleDetail,
                  arguments: c['capsuleId'] as String,
                ),
                onLongPress: () => _confirmDelete(
                  context,
                  c['capsuleId'] as String,
                  c['name'] as String? ?? 'Untitled',
                ),
              )),

          // ── Shared with you ───────────────────────────────────
          if (_collaboratorCapsules.isNotEmpty) ...[
            if (ownCapsules.isNotEmpty || _pendingCapsules.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: Colors.white.withOpacity(0.08))),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('shared with you',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.0,
                          )),
                    ),
                    Expanded(
                        child: Divider(
                            color: Colors.white.withOpacity(0.08))),
                  ],
                ),
              ),
            ..._collaboratorCapsules.map((c) => _CapsuleCard(
                  data: c,
                  isCollaborator: true,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRouter.capsuleDetail,
                    arguments: c['capsuleId'] as String,
                  ),
                  onLongPress: () {},
                )),
          ],
        ],
      ),
    );
  }
}

// ─── Declined Banner ─────────────────────────────────────────────────────────

class _DeclinedBanner extends StatelessWidget {
  final Map<String, dynamic> invite;
  final VoidCallback onDismiss;

  const _DeclinedBanner({required this.invite, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final username = invite['declinedUsername'] as String? ?? '';
    final name = username.isNotEmpty ? '@$username' : 'Someone';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.red.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Text('❌', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$name declined your capsule invite.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close,
                color: Colors.white.withOpacity(0.3), size: 18),
          ),
        ],
      ),
    );
  }
}

// ─── Invite Banner ────────────────────────────────────────────────────────────

class _InviteBanner extends StatelessWidget {
  final Map<String, dynamic> invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InviteBanner({
    required this.invite,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final fromUsername = invite['fromUsername'] as String? ?? '';
    final subtitle = fromUsername.isNotEmpty
        ? '@$fromUsername added you to a sealed capsule.'
        : 'Someone added you to a sealed capsule.';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📦', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Capsule invite',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onDecline,
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Decline',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onAccept,
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Accept',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Pending Capsule Card ─────────────────────────────────────────────────────

class _PendingCapsuleCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _PendingCapsuleCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Untitled').toString();
    final emoji = (data['emoji'] ?? '📦').toString();
    final count = (data['pendingInviteCount'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.cardDark2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child:
                        Text(emoji, style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      'Waiting for $count person${count == 1 ? '' : 's'} to respond',
                      style: TextStyle(
                        color: Colors.orange.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Pending',
                    style: TextStyle(
                      color: Colors.orange.withOpacity(0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Welcome Sheet ────────────────────────────────────────────────────────────

class _WelcomeSheet extends StatelessWidget {
  const _WelcomeSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          const Text('📦', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 20),
          const Text('Welcome to Boxed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 12),
          Text(
            'Seal memories today - photos, notes, anything that matters.\nSet a date. Open it when the time is right.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 14,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _featureRow(
              '🔒', 'End-to-end encrypted', 'Your memories, only yours'),
          const SizedBox(height: 14),
          _featureRow('⏳', 'Time-locked capsules',
              'Sealed until the day you choose'),
          const SizedBox(height: 14),
          _featureRow(
              '🎉', 'The reveal moment', 'Confetti when you finally open it'),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Create my first capsule →',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(String emoji, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

// ─── Animated Empty State ─────────────────────────────────────────────────────

class _EmptyState extends StatefulWidget {
  final CapsuleFilter filter;
  final VoidCallback onCreateTap;

  const _EmptyState({required this.filter, required this.onCreateTap});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAll = widget.filter == CapsuleFilter.all;
    final isUpcoming = widget.filter == CapsuleFilter.upcoming;
    final emoji = isAll ? '📦' : isUpcoming ? '⏳' : '🔓';
    final headline = isAll
        ? 'Seal your first memory'
        : isUpcoming
            ? 'No upcoming capsules'
            : 'Nothing unlocked yet';
    final subtext = isAll
        ? 'Drop in photos, notes or voice memos.\nOpen them when the time is right.'
        : isUpcoming
            ? 'Create a capsule and set a future unlock date.'
            : 'Sealed capsules will appear here once they open.';

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 38))),
                ),
                const SizedBox(height: 20),
                Text(headline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(subtext,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center),
                if (isAll) ...[
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: widget.onCreateTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Create your first capsule',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shimmer Card ─────────────────────────────────────────────────────────────

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Shimmer.fromColors(
        baseColor: AppTheme.cardDark,
        highlightColor: AppTheme.cardDark2,
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ─── Capsule Card ─────────────────────────────────────────────────────────────

class _CapsuleCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isCollaborator;

  const _CapsuleCard({
    required this.data,
    required this.onTap,
    required this.onLongPress,
    this.isCollaborator = false,
  });

  String _timeLabel(DateTime unlockDate, bool isUnlocked) {
    if (isUnlocked) {
      final diff = DateTime.now().difference(unlockDate);
      if (diff.inDays >= 1)
        return 'Opened ${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
      if (diff.inHours >= 1)
        return 'Opened ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
      return 'Just opened';
    } else {
      final diff = unlockDate.difference(DateTime.now());
      if (diff.inDays >= 1)
        return 'Opens in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
      if (diff.inHours >= 1)
        return 'Opens in ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
      return 'Opens in ${diff.inMinutes} min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Untitled').toString();
    final emoji = (data['emoji'] ?? '📦').toString();
    final unlockDate = DateTime.tryParse(data['unlockDate'] ?? '');
    final isUnlocked =
        unlockDate != null && DateTime.now().isAfter(unlockDate);
    final unlockStr = unlockDate != null
        ? DateFormat('MMM d, yyyy').format(unlockDate.toLocal())
        : '';
    final timeLabel =
        unlockDate != null ? _timeLabel(unlockDate, isUnlocked) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(
                color: isUnlocked
                    ? AppTheme.green.withOpacity(0.6)
                    : AppTheme.blue.withOpacity(0.6),
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.cardDark2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (isCollaborator)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('shared',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                )),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(unlockStr,
                        style: const TextStyle(
                            color: AppTheme.mutedText2, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? AppTheme.green.withOpacity(0.15)
                          : AppTheme.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isUnlocked ? 'Unlocked' : 'Locked',
                      style: TextStyle(
                        color: isUnlocked
                            ? AppTheme.green
                            : AppTheme.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(timeLabel,
                      style: const TextStyle(
                          color: AppTheme.mutedText, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}