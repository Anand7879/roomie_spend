// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/activity_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/stats_provider.dart';
import '../../models/group_model.dart';
import '../../models/activity_model.dart';
import '../../models/stats_model.dart';
import '../onboarding/onboarding_screen.dart';
import 'activity_history_screen.dart';

/// A premium production-ready roommate expense dashboard UI.
/// Matches the exact designer specifications from the reference image.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late PageController _pageController;
  int _activeGroupPage = 0;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon 👋';
    return 'Good Evening 👋';
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(recentActivitiesProvider);
    ref.invalidate(groupProvider);
    ref.invalidate(statsProvider);
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    ref.listen<AuthState>(authStateNotifierProvider, (previous, next) {
      if (next is AuthUnauthenticated) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const OnboardingScreen(),
          ),
          (route) => false,
        );
      }
    });

    final authState = ref.watch(authStateNotifierProvider);
    final stats = ref.watch(statsProvider);
    final groups = ref.watch(groupProvider);
    final activitiesAsync = ref.watch(recentActivitiesProvider);

    String userName = "Anand Patel";
    String avatarEmoji = "🧑";

    if (authState is AuthAuthenticated) {
      userName = authState.user.name;
      avatarEmoji =
          authState.user.avatar.isNotEmpty ? authState.user.avatar : "🧑";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: AppTheme.primaryPurple,
              backgroundColor: Colors.white,
              edgeOffset: 60,
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1.0 - _fadeAnimation.value)),
                      child: child,
                    ),
                  );
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(
                      left: 18, right: 18, top: 8, bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──
                      _buildHeader(userName, avatarEmoji, context),
                      const SizedBox(height: 18),

                      // ── Balance Card ──
                      _buildBalanceCard(stats, context),
                      const SizedBox(height: 22),

                      // ── Dashboard Overview ──
                      _buildSectionHeader(
                        "Dashboard Overview",
                        "See all",
                        () => _showComingSoon(context, "Full Overview Analytics"),
                      ),
                      const SizedBox(height: 12),
                      _buildStatsGrid(stats, isTablet),
                      const SizedBox(height: 18),

                      // ── Action Buttons ──
                      _buildActionButtons(context, groups),
                      const SizedBox(height: 22),

                      // ── Recent Groups ──
                      _buildSectionHeader(
                        "Recent Groups",
                        "See all",
                        () => _showComingSoon(context, "All Groups list"),
                      ),
                      const SizedBox(height: 12),
                      _buildGroupsSlider(groups),
                      const SizedBox(height: 22),

                      // ── Quick Actions ──
                      const Text(
                        "Quick Actions",
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildQuickActions(context, groups),
                      const SizedBox(height: 22),

                      // ── Recent Activities ──
                      _buildActivitiesHeader(context),
                      const SizedBox(height: 12),
                      activitiesAsync.when(
                        data: (activities) {
                          if (activities.isEmpty) {
                            return _buildEmptyActivities(context);
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: activities.length > 5
                                ? 5
                                : activities.length,
                            separatorBuilder: (_, a) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _buildActivityRow(activities[i]),
                          );
                        },
                        loading: () => _buildActivitySkeleton(),
                        error: (e, _) => _buildErrorState(e),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Floating Action Button ──
          Positioned(
            right: 18,
            bottom: 86,
            child: _buildFAB(context, groups),
          ),

          // ── Bottom Navigation ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(String name, String avatar, BuildContext context) {
    return Row(
      children: [
        // Avatar
        GestureDetector(
          onTap: () => _showProfileMenu(context, name, avatar),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FF),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppTheme.primaryPurple.withOpacity(0.35), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                avatar,
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Greeting + Name
        Expanded(
          child: GestureDetector(
            onTap: () => _showProfileMenu(context, name, avatar),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Premium Badge
        GestureDetector(
          onTap: () => _showPremiumDialog(context),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD166), Color(0xFFEFAA0D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF7B538).withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 15),
                SizedBox(width: 5),
                Text(
                  'Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Notification Bell
        GestureDetector(
          onTap: () => _showNotifications(context),
          child: Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppTheme.textPrimary,
                  size: 22,
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BALANCE CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBalanceCard(DashboardStats stats, BuildContext context) {
    final net = stats.netBalance;
    final isPos = net >= 0;

    return Container(
      width: double.infinity,
      height: 185,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF7B6EF6), Color(0xFF5046D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // Wave + 3D wallet painter
            Positioned.fill(
              child: CustomPaint(painter: _WalletCardPainter()),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top row: label + View Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL NET BALANCE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            _showComingSoon(context, "Balance Breakdown"),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.chevron_right_rounded,
                                  color: Colors.white, size: 13),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Big balance amount
                  AnimatedCounter(
                    value: net,
                    prefix: isPos ? '+₹' : '₹',
                    decimals: 0,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),

                  // Bottom split row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildBalancePill(
                            title: 'You Owe',
                            amount: stats.youOwe,
                            isOwe: true),
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withOpacity(0.25),
                        ),
                        _buildBalancePill(
                            title: 'You Get',
                            amount: stats.youGet,
                            isOwe: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalancePill(
      {required String title,
      required double amount,
      required bool isOwe}) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isOwe
                ? const Color(0xFFFFECEF)
                : const Color(0xFFE6FBF0),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOwe
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: isOwe
                ? const Color(0xFFEF4444)
                : const Color(0xFF22C55E),
            size: 14,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedCounter(
              value: amount,
              prefix: '₹',
              decimals: 0,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION HEADER (reusable)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(
      String title, String action, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Text(
                action,
                style: const TextStyle(
                  color: AppTheme.primaryPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.primaryPurple, size: 15),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATS GRID (4 cards in 2x2 or 1x4)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStatsGrid(DashboardStats stats, bool isTablet) {
    final cards = [
      {
        'title': "Today's Spending",
        'value': stats.todaySpending,
        'icon': Icons.calendar_today_rounded,
        'color': AppTheme.primaryPurple,
        'prefix': '₹',
      },
      {
        'title': "Monthly Spending",
        'value': stats.monthlySpending,
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFF22C55E),
        'prefix': '₹',
      },
      {
        'title': "Active Groups",
        'value': stats.activeGroups.toDouble(),
        'icon': Icons.groups_rounded,
        'color': const Color(0xFFF59E0B),
        'prefix': '',
      },
      {
        'title': "Pending Settlements",
        'value': stats.pendingSettlements.toDouble(),
        'icon': Icons.receipt_long_rounded,
        'color': const Color(0xFFEF4444),
        'prefix': '',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) {
        final card = cards[i];
        final color = card['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // sparkle top-right
              Positioned(
                right: 0,
                top: 0,
                child: Opacity(
                  opacity: 0.22,
                  child: Text('+ · ·',
                      style: TextStyle(color: color, fontSize: 11)),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(card['icon'] as IconData,
                        color: color, size: 16),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedCounter(
                        value: card['value'] as double,
                        prefix: card['prefix'] as String,
                        decimals: 0,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card['title'] as String,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTION BUTTONS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildActionButtons(
      BuildContext context, List<GroupModel> groups) {
    return Row(
      children: [
        // Create Group
        Expanded(
          child: GestureDetector(
            onTap: () => _showCreateGroupDialog(context),
            child: Container(
              height: 80,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9589FF), Color(0xFF6C63FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.groups_rounded,
                        color: Color(0xFF6C63FF), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Create Group',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            )),
                        SizedBox(height: 2),
                        Text('Start a new group',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            )),
                      ],
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Add Expense
        Expanded(
          child: GestureDetector(
            onTap: () => _showAddExpenseDialog(context, groups),
            child: Container(
              height: 80,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF34D399), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Add Expense',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            )),
                        SizedBox(height: 2),
                        Text('Split a new expense',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            )),
                      ],
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GROUPS SLIDER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGroupsSlider(List<GroupModel> groups) {
    if (groups.isEmpty) {
      return Container(
        height: 110,
        alignment: Alignment.center,
        child: const Text('No groups yet. Tap Create Group to start!',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _pageController,
            itemCount: groups.length,
            onPageChanged: (p) => setState(() => _activeGroupPage = p),
            itemBuilder: (_, index) {
              final g = groups[index];
              final isPositive = g.balance >= 0;
              final balText = g.balance == 0
                  ? 'Settled'
                  : g.balance > 0
                      ? 'Gets ₹${g.balance.toStringAsFixed(0)}'
                      : 'Owes ₹${g.balance.abs().toStringAsFixed(0)}';
              final balColor = g.balance == 0
                  ? AppTheme.textMuted
                  : isPositive
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444);

              return Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Group icon + name + members
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F5FF),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppTheme.borderLight, width: 1),
                          ),
                          child: Center(
                            child: Text(g.imageUrl,
                                style: const TextStyle(fontSize: 19)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${g.memberCount} members',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Last activity
                    Text(
                      g.lastActivity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    // Balance + arrow
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          balText,
                          style: TextStyle(
                            color: balColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _openGroupDetail(context, g),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: AppTheme.lightPurpleContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_rounded,
                                color: AppTheme.primaryPurple, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(groups.length, (i) {
            final sel = i == _activeGroupPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: sel ? 10 : 6,
              height: sel ? 10 : 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sel
                    ? AppTheme.primaryPurple
                    : const Color(0xFFD1D5DB),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUICK ACTIONS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildQuickActions(
      BuildContext context, List<GroupModel> groups) {
    final actions = [
      {
        'label': 'Import SMS',
        'icon': Icons.sms_outlined,
        'color': AppTheme.primaryPurple,
        'onTap': () => _simulateSmsImport(context),
      },
      {
        'label': 'Scan Receipt',
        'icon': Icons.qr_code_scanner_rounded,
        'color': const Color(0xFF3B82F6),
        'onTap': () => _simulateReceiptScan(context),
      },
      {
        'label': 'Recurring Bills',
        'icon': Icons.autorenew_rounded,
        'color': const Color(0xFFEC4899),
        'onTap': () => _showComingSoon(context, 'Recurring Bills'),
      },
      {
        'label': 'Analytics',
        'icon': Icons.show_chart_rounded,
        'color': const Color(0xFF6366F1),
        'onTap': () => _showComingSoon(context, 'Spend Analytics'),
      },
      {
        'label': 'Settle Up',
        'icon': Icons.handshake_rounded,
        'color': const Color(0xFF22C55E),
        'onTap': () => _showSettleUpDialog(context, groups),
      },
    ];

    return Row(
      children: actions.map((act) {
        final color = act['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: act['onTap'] as VoidCallback,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.025),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(act['icon'] as IconData,
                        color: color, size: 20),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    act['label'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECENT ACTIVITIES HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildActivitiesHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Recent Activities",
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const ActivityHistoryScreen()),
            );
          },
          style: TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'View All',
            style: TextStyle(
              color: AppTheme.primaryPurple,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIVITY ROW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildActivityRow(ActivityModel activity) {
    final isCredit =
        activity.type == ActivityType.settlementCompleted;
    final isNeutral = activity.type == ActivityType.groupCreated ||
        activity.type == ActivityType.memberJoined ||
        activity.type == ActivityType.reminderSent;

    final iconData = _getActivityIcon(activity.type);
    final iconColor = _getActivityColor(activity.type);

    final amountColor = isNeutral
        ? AppTheme.primaryPurple
        : isCredit
            ? const Color(0xFF22C55E)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${activity.description} • ${_timeAgo(activity.timestamp)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              if (activity.amount != null)
                Text(
                  '₹${activity.amount!.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: amountColor,
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF), size: 17),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivities(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      child: Column(
        children: [
          const Icon(Icons.history_toggle_off_rounded,
              color: AppTheme.primaryPurple, size: 44),
          const SizedBox(height: 12),
          const Text('No recent activity yet.',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Activities performed by you will sync here in real time.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await ref
                    .read(activityServiceProvider)
                    .seedMockActivities();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Seeded mock activities to Firestore!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Failed to seed: $e'),
                        backgroundColor: AppTheme.errorRed),
                  );
                }
              }
            },
            icon: const Icon(Icons.bolt_rounded, size: 16),
            label: const Text('Seed Test Activities',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySkeleton() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (_, a) => const SizedBox(height: 10),
      itemBuilder: (_, b) => Container(
        height: 65,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const PulseSkeleton(width: 42, height: 42, borderRadius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  PulseSkeleton(width: 130, height: 12, borderRadius: 4),
                  SizedBox(height: 6),
                  PulseSkeleton(width: 90, height: 10, borderRadius: 4),
                ],
              ),
            ),
            const Row(
              children: [
                PulseSkeleton(width: 40, height: 12, borderRadius: 4),
                SizedBox(width: 5),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey, size: 15),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Error: $error',
                style: const TextStyle(
                    color: AppTheme.errorRed, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FLOATING ACTION BUTTON
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFAB(BuildContext context, List<GroupModel> groups) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF8B7CFF), Color(0xFF6C63FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.42),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _showAddExpenseDialog(context, groups),
          child: const Center(
            child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTTOM NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final tabs = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.groups_rounded, 'label': 'Groups'},
      {'icon': Icons.bar_chart_rounded, 'label': 'Analytics'},
      {'icon': Icons.receipt_long_rounded, 'label': 'Bills'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'Balances'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final selected = i == _currentNavIndex;

              return GestureDetector(
                onTap: () => setState(() => _currentNavIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: selected
                      ? const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8)
                      : const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primaryPurple.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: selected
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tab['icon'] as IconData,
                                color: AppTheme.primaryPurple, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              tab['label'] as String,
                              style: const TextStyle(
                                color: AppTheme.primaryPurple,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tab['icon'] as IconData,
                                color: AppTheme.textMuted, size: 20),
                            const SizedBox(height: 2),
                            Text(
                              tab['label'] as String,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER METHODS
  // ─────────────────────────────────────────────────────────────────────────
  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.expenseAdded:
        return Icons.shopping_bag_outlined;
      case ActivityType.expenseUpdated:
        return Icons.edit_note_rounded;
      case ActivityType.expenseDeleted:
        return Icons.delete_outline_rounded;
      case ActivityType.groupCreated:
        return Icons.group_add_rounded;
      case ActivityType.memberJoined:
        return Icons.person_add_rounded;
      case ActivityType.settlementCompleted:
        return Icons.handshake_outlined;
      case ActivityType.reminderSent:
        return Icons.notifications_active_outlined;
      case ActivityType.billImported:
        return Icons.receipt_long_rounded;
      case ActivityType.receiptScanned:
        return Icons.document_scanner_outlined;
    }
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.expenseAdded:
        return AppTheme.primaryPurple;
      case ActivityType.expenseUpdated:
        return Colors.orange;
      case ActivityType.expenseDeleted:
        return AppTheme.errorRed;
      case ActivityType.groupCreated:
        return Colors.teal;
      case ActivityType.memberJoined:
        return Colors.indigo;
      case ActivityType.settlementCompleted:
        return AppTheme.successGreen;
      case ActivityType.reminderSent:
        return Colors.pink;
      case ActivityType.billImported:
        return Colors.blue;
      case ActivityType.receiptScanned:
        return AppTheme.secondaryViolet;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${dt.day}/${dt.month}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DIALOGS
  // ─────────────────────────────────────────────────────────────────────────
  void _showProfileMenu(
      BuildContext context, String userName, String avatar) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: AppTheme.lightPurpleContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(avatar,
                          style: const TextStyle(fontSize: 32)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Roommate Account',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.settings_outlined,
                    color: AppTheme.textPrimary),
                title: const Text('Account Settings',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded,
                    color: AppTheme.textPrimary),
                title: const Text('Help & Support',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded,
                    color: AppTheme.errorRed),
                title: const Text('Sign Out',
                    style: TextStyle(
                        color: AppTheme.errorRed,
                        fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(authStateNotifierProvider.notifier)
                      .logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded,
                color: Color(0xFFFB8500), size: 28),
            SizedBox(width: 8),
            Text('RoomieSpend Pro',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unlock elite roommate features:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 14)),
            SizedBox(height: 12),
            BulletPoint(text: 'Automatic SMS Bank alert scanner'),
            BulletPoint(text: 'Unlimited receipt OCR Scanning'),
            BulletPoint(text: 'Advanced room budgeting analytics'),
            BulletPoint(text: 'Priority cloud synchronization'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('RoomieSpend Pro is coming soon!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Upgrade - ₹99/mo'),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('You have 3 pending settlements to confirm.')),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('$feature is coming soon in RoomieSpend Pro!')),
    );
  }

  void _openGroupDetail(BuildContext context, GroupModel group) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(group.imageUrl,
                    style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text('${group.memberCount} members active',
                        style:
                            const TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Recent Group Actions:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(group.lastActivity,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Open Room Chat & History'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emojis = ["🏠", "🌴", "💼", "🚗", "🏖️", "🎮", "🎸", "🍕"];
    String selectedEmoji = emojis[0];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: const Text('Create Roomie Group',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'e.g. Flatmates 402',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Choose Icon:',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold))),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: emojis.length,
                  itemBuilder: (_, i) {
                    final e = emojis[i];
                    final isSel = e == selectedEmoji;
                    return GestureDetector(
                      onTap: () => setDs(() => selectedEmoji = e),
                      child: Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppTheme.lightPurpleContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel
                                ? AppTheme.primaryPurple
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Text(e,
                            style: const TextStyle(fontSize: 18)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                final newGroup = GroupModel(
                  id: 'g_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  imageUrl: selectedEmoji,
                  memberCount: 2,
                  lastActivity: 'Group created just now',
                  balance: 0.0,
                );
                ref.read(groupProvider.notifier).addGroup(newGroup);
                await ref.read(activityServiceProvider).logActivity(
                      type: ActivityType.groupCreated,
                      title: 'You created Group: $name',
                      description: 'Room group initialized',
                      groupName: name,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Group "$name" created and synced!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseDialog(
      BuildContext context, List<GroupModel> groups) {
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please create a group first!')),
      );
      return;
    }

    final amtCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    GroupModel selGroup = groups[0];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: const Text('Add Room Expense',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<GroupModel>(
                  value: selGroup,
                  items: groups
                      .map((g) => DropdownMenuItem(
                            value: g,
                            child: Text('${g.imageUrl} ${g.name}'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDs(() => selGroup = v);
                  },
                  decoration: InputDecoration(
                    labelText: 'Select Group',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Expense Description',
                    hintText: 'e.g. Grocery Run',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amtCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    hintText: '0.00',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amount =
                    double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                if (title.isEmpty || amount <= 0) return;
                Navigator.pop(ctx);
                final split = amount / selGroup.memberCount;
                final delta = amount - split;
                ref.read(groupProvider.notifier).updateLastActivity(
                    selGroup.id, 'You added $title', delta);
                ref.read(statsProvider.notifier).addSpend(amount);
                await ref.read(activityServiceProvider).logActivity(
                      type: ActivityType.expenseAdded,
                      title: 'You added $title',
                      description: selGroup.name,
                      amount: amount,
                      groupName: selGroup.name,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Expense of ₹${amount.toStringAsFixed(0)} saved!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettleUpDialog(
      BuildContext context, List<GroupModel> groups) {
    final outstanding = groups.where((g) => g.balance != 0).toList();
    if (outstanding.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All groups are completely settled! 🥳')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: const Text('Settle Up Balances',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: outstanding.length,
            itemBuilder: (_, i) {
              final g = outstanding[i];
              final isOwe = g.balance < 0;
              final abs = g.balance.abs();
              return ListTile(
                leading: Text(g.imageUrl,
                    style: const TextStyle(fontSize: 24)),
                title: Text(g.name,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  isOwe
                      ? 'You pay ₹${abs.toStringAsFixed(0)}'
                      : 'You receive ₹${abs.toStringAsFixed(0)}',
                  style: TextStyle(
                      color: isOwe
                          ? AppTheme.errorRed
                          : AppTheme.successGreen),
                ),
                trailing: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    ref
                        .read(groupProvider.notifier)
                        .updateLastActivity(
                            g.id, 'You settled balances', -g.balance);
                    ref.read(statsProvider.notifier).settleOne();
                    await ref
                        .read(activityServiceProvider)
                        .logActivity(
                          type: ActivityType.settlementCompleted,
                          title: 'You settled with ${g.name}',
                          description: isOwe
                              ? 'Paid ₹${abs.toStringAsFixed(0)}'
                              : 'Received ₹${abs.toStringAsFixed(0)}',
                          amount: abs,
                          groupName: g.name,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Settlement of ₹${abs.toStringAsFixed(0)} synced!')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lightPurpleContainer,
                    foregroundColor: AppTheme.primaryPurple,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Settle'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  Future<void> _simulateSmsImport(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Row(
          children: [
            CircularProgressIndicator(color: AppTheme.primaryPurple),
            SizedBox(width: 20),
            Text('Scanning SMS bank alerts...',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1500));
    if (context.mounted) Navigator.pop(context);

    const amount = 999.0;
    final group = ref.read(groupProvider).first;
    ref.read(groupProvider.notifier).updateLastActivity(
        group.id, 'You imported Wifi Bill', amount - (amount / group.memberCount));
    ref.read(statsProvider.notifier).addSpend(amount);
    await ref.read(activityServiceProvider).logActivity(
          type: ActivityType.billImported,
          title: 'You imported Wifi Bill',
          description: 'HDFC Bank transaction parsed (₹$amount)',
          amount: amount,
          groupName: group.name,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('SMS transaction from HDFC imported!')),
      );
    }
  }

  Future<void> _simulateReceiptScan(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Row(
          children: [
            CircularProgressIndicator(color: AppTheme.primaryPurple),
            SizedBox(width: 20),
            Text('Processing receipt OCR...',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1500));
    if (context.mounted) Navigator.pop(context);

    const amount = 2450.0;
    final group = ref.read(groupProvider).first;
    ref.read(groupProvider.notifier).updateLastActivity(
        group.id,
        'You scanned Diner Receipt',
        amount - (amount / group.memberCount));
    ref.read(statsProvider.notifier).addSpend(amount);
    await ref.read(activityServiceProvider).logActivity(
          type: ActivityType.receiptScanned,
          title: 'You scanned Dinner Receipt',
          description: 'OCR scan completed successfully (₹$amount)',
          amount: amount,
          groupName: group.name,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Receipt scanned! Added Dinner bill ₹2450.')),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WALLET CARD PAINTER — draws waves + 3D wallet + coins on balance card
// ═══════════════════════════════════════════════════════════════════════════
class _WalletCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle wave overlay
    final wavePaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    final wave1 = Path()
      ..moveTo(size.width * 0.52, size.height)
      ..quadraticBezierTo(size.width * 0.70, size.height * 0.2,
          size.width, size.height * 0.42)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(wave1, wavePaint);
    final wave2 = Path()
      ..moveTo(size.width * 0.42, size.height)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.50,
          size.width, size.height * 0.68)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(wave2, wavePaint);

    // Green leaf shapes
    final leafPaint = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.38)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(size.width * 0.80, size.height * 0.28);
    canvas.rotate(-0.38);
    canvas.drawOval(const Rect.fromLTWH(0, 0, 14, 26), leafPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(size.width * 0.91, size.height * 0.22);
    canvas.rotate(0.28);
    canvas.drawOval(const Rect.fromLTWH(0, 0, 12, 22), leafPaint);
    canvas.restore();

    // 3D Wallet body
    canvas.save();
    canvas.translate(size.width * 0.78, size.height * 0.40);
    canvas.rotate(-0.14);

    // Green card sticking out
    final cardPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, -9, 20, 16), const Radius.circular(4)),
      cardPaint,
    );

    // Main wallet
    final walletPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF5B3FF3), Color(0xFF3A1FC0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(0, 0, 50, 38))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 50, 38), const Radius.circular(9)),
      walletPaint,
    );

    // Wallet flap
    final flapPaint = Paint()
      ..color = const Color(0xFF2E159F)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, 9, 30, 13), const Radius.circular(4)),
      flapPaint,
    );

    // Gold button on flap
    canvas.drawCircle(
      const Offset(42, 15),
      3.5,
      Paint()
        ..color = const Color(0xFFFFD166)
        ..style = PaintingStyle.fill,
    );

    canvas.restore();

    // Gold coins
    final coinFill = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD166), Color(0xFFF7B538)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 8))
      ..style = PaintingStyle.fill;
    final coinEdge = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    void coin(double x, double y, double r) {
      canvas.drawCircle(Offset(x, y), r, coinFill);
      canvas.drawCircle(Offset(x, y), r, coinEdge);
      canvas.drawCircle(Offset(x, y), r * 0.58, coinEdge);
    }

    coin(size.width * 0.72, size.height * 0.42, 6);
    coin(size.width * 0.86, size.height * 0.76, 7.5);
    coin(size.width * 0.88, size.height * 0.80, 7.5);
    coin(size.width * 0.90, size.height * 0.84, 7.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// ANIMATED COUNTER
// ═══════════════════════════════════════════════════════════════════════════
class AnimatedCounter extends StatefulWidget {
  final num value;
  final String prefix;
  final String suffix;
  final TextStyle style;
  final int decimals;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    required this.style,
    this.decimals = 0,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _anim = Tween<double>(begin: 0, end: widget.value.toDouble())
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(
              begin: _anim.value, end: widget.value.toDouble())
          .animate(
              CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, w) => Text(
        '${widget.prefix}${_anim.value.toStringAsFixed(widget.decimals)}${widget.suffix}',
        style: widget.style,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════
class BulletPoint extends StatelessWidget {
  final String text;
  const BulletPoint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: Color(0xFF22C55E), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.3)),
          ),
        ],
      ),
    );
  }
}

class PulseSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  const PulseSkeleton(
      {super.key,
      required this.width,
      required this.height,
      this.borderRadius = 8});

  @override
  State<PulseSkeleton> createState() => _PulseSkeletonState();
}

class _PulseSkeletonState extends State<PulseSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this)
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, x) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
      ),
    );
  }
}
