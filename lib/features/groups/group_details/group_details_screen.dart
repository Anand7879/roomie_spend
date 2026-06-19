// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/group_model.dart';
import '../../../models/expense_model.dart';
import '../../../providers/group_detail_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../invites/invite_friends_screen.dart';

class GroupDetailsScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final String groupIcon;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.groupIcon,
  });

  @override
  ConsumerState<GroupDetailsScreen> createState() =>
      _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends ConsumerState<GroupDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() => _selectedTab = _tabController.index);
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));

    return groupAsync.when(
      data: (group) => _buildScaffold(group),
      loading: () => _buildLoadingScaffold(),
      error: (e, _) => _buildErrorScaffold(e),
    );
  }

  Widget _buildScaffold(GroupModel? group) {
    if (group == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.group_off_rounded,
                  size: 56, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              const Text('Group not found.',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final expensesAsync =
        ref.watch(groupExpensesProvider(widget.groupId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
          _buildSliverAppBar(group, innerBoxIsScrolled),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 0 — Expenses
            expensesAsync.when(
              data: (expenses) => _buildExpensesTab(expenses, group),
              loading: () => _buildTabSkeleton(),
              error: (e, _) => _buildTabError(e),
            ),
            // Tab 1 — Summary
            expensesAsync.when(
              data: (expenses) => _buildSummaryTab(
                  expenses.cast<ExpenseModel>(), group),
              loading: () => _buildTabSkeleton(),
              error: (e, _) => _buildTabError(e),
            ),
            // Tab 2 — Balances
            expensesAsync.when(
              data: (expenses) => _buildBalancesTab(
                  expenses.cast<ExpenseModel>(), group),
              loading: () => _buildTabSkeleton(),
              error: (e, _) => _buildTabError(e),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(group),
    );
  }

  // ─── Sliver App Bar ────────────────────────────────────────────────────

  Widget _buildSliverAppBar(GroupModel group, bool innerBoxIsScrolled) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: innerBoxIsScrolled ? 1 : 0,
      scrolledUnderElevation: 1,
      leading: Container(
        margin: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.share_rounded,
                color: AppTheme.primaryPurple, size: 19),
            onPressed: () => _showShareSheet(context, group),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          margin: const EdgeInsets.only(top: 6, bottom: 6, right: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: AppTheme.textPrimary, size: 19),
            onPressed: () {},
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _GroupHeroCard(group: group),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          color: Colors.white,
          child: _buildCustomTabBar(),
        ),
      ),
    );
  }

  Widget _buildCustomTabBar() {
    const labels = ['Expenses', 'Summary', 'Balances'];
    const icons = [
      Icons.receipt_long_rounded,
      Icons.bar_chart_rounded,
      Icons.account_balance_wallet_rounded,
    ];

    return Row(
      children: List.generate(3, (i) {
        final isSelected = _selectedTab == i;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _tabController.animateTo(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryPurple
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icons[i],
                    size: 15,
                    color: isSelected
                        ? AppTheme.primaryPurple
                        : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    labels[i],
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.primaryPurple
                          : AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // ─── Quick Actions ─────────────────────────────────────────────────────

  Widget _buildQuickActions(GroupModel group) {
    final actions = [
      {
        'icon': Icons.file_download_outlined,
        'label': 'Export',
        'color': AppTheme.primaryPurple,
        'onTap': () => _comingSoon('Export'),
      },
      {
        'icon': Icons.chat_bubble_outline_rounded,
        'label': 'Chat',
        'color': const Color(0xFF3B82F6),
        'onTap': () => _comingSoon('Chat'),
      },
      {
        'icon': Icons.autorenew_rounded,
        'label': 'Recurring',
        'color': const Color(0xFFEC4899),
        'onTap': () => _comingSoon('Recurring'),
      },
      {
        'icon': Icons.settings_outlined,
        'label': 'Settings',
        'color': const Color(0xFF6B7280),
        'onTap': () => _comingSoon('Settings'),
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((a) {
          final color = a['color'] as Color;
          return GestureDetector(
            onTap: a['onTap'] as VoidCallback,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a['icon'] as IconData,
                      color: color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  a['label'] as String,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Expenses Tab ──────────────────────────────────────────────────────

  Widget _buildExpensesTab(List<dynamic> raw, GroupModel group) {
    final expenses = raw.cast<ExpenseModel>();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildQuickActions(group),
              const SizedBox(height: 20),
            ],
          ),
        ),
        if (expenses.isEmpty) ...[
          SliverToBoxAdapter(child: _buildEmptyExpensesState(group)),
        ] else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Expenses',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${expenses.length} total',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final expense = expenses[i];
                return _ExpenseCard(expense: expense, group: group);
              },
              childCount: expenses.length,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildEmptyExpensesState(GroupModel group) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Illustration
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.lightPurpleContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 20,
                  right: 30,
                  child: _FloatingEmoji(emoji: '💸', size: 32, delay: 0),
                ),
                Positioned(
                  bottom: 20,
                  left: 30,
                  child: _FloatingEmoji(emoji: '🧾', size: 28, delay: 300),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppTheme.lightPurpleContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppTheme.primaryPurple,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Add Your First Expense',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Track shared costs with your group',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Add Expense CTA
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _showAddExpenseSheet(group),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
              icon: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 20),
              label: const Text(
                'Add Expense',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Divider or
          Row(
            children: [
              Expanded(
                  child: Divider(
                      color: AppTheme.borderLight, thickness: 1.5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(
                  child: Divider(
                      color: AppTheme.borderLight, thickness: 1.5)),
            ],
          ),
          const SizedBox(height: 20),

          // Invite Friends Card
          _InviteFriendsCard(
            groupId: widget.groupId,
            groupName: group.groupName,
            groupIcon: widget.groupIcon,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── Summary Tab ───────────────────────────────────────────────────────

  Widget _buildSummaryTab(List<ExpenseModel> expenses, GroupModel group) {
    final total =
        expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final avg = group.memberCount > 0 ? total / group.memberCount : 0.0;

    // Monthly buckets
    final now = DateTime.now();
    final thisMonth = expenses
        .where((e) =>
            e.date.year == now.year && e.date.month == now.month)
        .fold<double>(0.0, (sum, e) => sum + e.amount);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 4),
          // Stats row
          Row(
            children: [
              Expanded(
                child: _SummaryStatCard(
                  label: 'Total Expenses',
                  value: '₹${total.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppTheme.primaryPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryStatCard(
                  label: 'Members',
                  value: '${group.memberCount}',
                  icon: Icons.people_rounded,
                  color: const Color(0xFF22C55E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryStatCard(
                  label: 'Avg per Person',
                  value: '₹${avg.toStringAsFixed(0)}',
                  icon: Icons.person_outline_rounded,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryStatCard(
                  label: 'This Month',
                  value: '₹${thisMonth.toStringAsFixed(0)}',
                  icon: Icons.calendar_today_rounded,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Monthly spending chart
          _MonthlySpendingChart(expenses: expenses),
          const SizedBox(height: 20),

          // Expense breakdown
          if (expenses.isNotEmpty)
            _ExpenseBreakdownCard(expenses: expenses),
        ],
      ),
    );
  }

  // ─── Balances Tab ──────────────────────────────────────────────────────

  Widget _buildBalancesTab(List<ExpenseModel> expenses, GroupModel group) {
    final authState = ref.read(authStateNotifierProvider);
    final currentUid =
        authState is AuthAuthenticated ? authState.user.uid : '';

    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppTheme.lightPurpleContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.handshake_rounded,
                  color: AppTheme.primaryPurple, size: 34),
            ),
            const SizedBox(height: 16),
            const Text(
              'All settled up!',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No outstanding balances.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Compute simple balances (who paid vs split)
    final Map<String, double> balances = {};
    for (final e in expenses) {
      balances[e.paidBy] = (balances[e.paidBy] ?? 0) + e.amount;
      final share = e.amount / e.splitAmong.length;
      for (final uid in e.splitAmong) {
        balances[uid] = (balances[uid] ?? 0) - share;
      }
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 4),
        ...balances.entries.map((entry) {
          final isMe = entry.key == currentUid;
          final isPos = entry.value >= 0;
          return _BalanceRow(
            label: isMe ? 'You' : 'Member',
            amount: entry.value,
            isPositive: isPos,
            isCurrentUser: isMe,
          );
        }),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withOpacity(0.28),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => _comingSoon('Settle Up'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
            icon: const Icon(Icons.handshake_rounded,
                color: Colors.white, size: 20),
            label: const Text(
              'Settle Up',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ─── FAB ───────────────────────────────────────────────────────────────

  Widget _buildFAB(GroupModel group) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF8B7CFF), Color(0xFF6C63FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withOpacity(0.38),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () => _showAddExpenseSheet(group),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  Widget _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryPurple),
      ),
    );
  }

  Widget _buildErrorScaffold(Object e) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Center(
        child: Text('Error: $e',
            style: const TextStyle(color: AppTheme.errorRed)),
      ),
    );
  }

  Widget _buildTabSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => _SkeletonBox(height: 72, borderRadius: 18),
    );
  }

  Widget _buildTabError(Object e) {
    return Center(
      child: Text('Error loading data: $e',
          style: const TextStyle(color: AppTheme.errorRed)),
    );
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: AppTheme.primaryPurple,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showShareSheet(BuildContext context, GroupModel group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _InviteFriendsCard(
        groupId: widget.groupId,
        groupName: group.groupName,
        groupIcon: widget.groupIcon,
        isSheet: true,
      ),
    );
  }

  void _showAddExpenseSheet(GroupModel group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _AddExpenseSheet(group: group, ref: ref),
    );
  }
}

// ─── Group Hero Card ───────────────────────────────────────────────────────

class _GroupHeroCard extends StatelessWidget {
  final GroupModel group;
  const _GroupHeroCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final isPositive = group.balance >= 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7B6EF6), Color(0xFF5046D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Wave bg
          Positioned.fill(child: CustomPaint(painter: _WavePainter())),
          // Content
          Padding(
            padding:
                const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.4), width: 2),
                      ),
                      child: Center(
                        child: Text(group.groupIcon,
                            style: const TextStyle(fontSize: 32)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.groupName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.people_rounded,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 13),
                              const SizedBox(width: 4),
                              Text(
                                '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  group.groupType,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Balance pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: isPositive
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFCA5A5),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        group.balance == 0
                            ? 'All settled up'
                            : isPositive
                                ? 'You get ₹${group.balance.toStringAsFixed(0)}'
                                : 'You owe ₹${group.balance.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Invite Friends Card ──────────────────────────────────────────────────

class _InviteFriendsCard extends StatelessWidget {
  final String groupId;
  final String groupName;
  final String groupIcon;
  final bool isSheet;

  const _InviteFriendsCard({
    required this.groupId,
    required this.groupName,
    required this.groupIcon,
    this.isSheet = false,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      {
        'icon': Icons.qr_code_rounded,
        'label': 'Scan QR',
        'color': AppTheme.primaryPurple,
        'bg': AppTheme.lightPurpleContainer,
      },
      {
        'icon': Icons.link_rounded,
        'label': 'Invite Link',
        'color': const Color(0xFF3B82F6),
        'bg': const Color(0xFFEFF6FF),
      },
      {
        'icon': Icons.contacts_rounded,
        'label': 'Contacts',
        'color': const Color(0xFF22C55E),
        'bg': const Color(0xFFF0FDF4),
      },
    ];

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: isSheet
          ? null
          : BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFBFDBFE), width: 1.5),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSheet) ...[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            isSheet ? 'Share "$groupName"' : 'Invite your roommates',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add members to start splitting expenses together.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: options.map((opt) {
              final color = opt['color'] as Color;
              final bg = opt['bg'] as Color;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (isSheet) {
                      Navigator.pop(context);
                    }
                    // Navigate to invite friends screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InviteFriendsScreen(
                          groupId: groupId,
                          groupName: groupName,
                          groupIcon: groupIcon,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(opt['icon'] as IconData,
                            color: color, size: 26),
                        const SizedBox(height: 6),
                        Text(
                          opt['label'] as String,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (isSheet) const SizedBox(height: 24),
        ],
      ),
    );

    return card;
  }
}

// ─── Expense Card ─────────────────────────────────────────────────────────

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final GroupModel group;

  const _ExpenseCard({required this.expense, required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.lightPurpleContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: AppTheme.primaryPurple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${expense.category} · ${_fmt(expense.date)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${expense.amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppTheme.errorRed,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}

// ─── Add Expense Sheet ────────────────────────────────────────────────────

class _AddExpenseSheet extends StatefulWidget {
  final GroupModel group;
  final WidgetRef ref;

  const _AddExpenseSheet({required this.group, required this.ref});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _titleCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amtCtrl.text.trim()) ?? 0.0;
    if (title.isEmpty || amount <= 0) return;

    setState(() => _saving = true);

    final authState = widget.ref.read(authStateNotifierProvider);
    if (authState is! AuthAuthenticated) return;

    final expense = ExpenseModel(
      id: '',
      groupId: widget.group.id,
      title: title,
      amount: amount,
      paidBy: authState.user.uid,
      splitAmong: widget.group.members,
      date: DateTime.now(),
      createdAt: DateTime.now(),
    );

    try {
      await widget.ref.read(groupFirestoreServiceProvider).addExpense(
            groupId: widget.group.id,
            expense: expense,
            addedByName: authState.user.name,
            groupName: widget.group.groupName,
            addedByUid: authState.user.uid,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add expense: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Expense to ${widget.group.groupName}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleCtrl,
              decoration: _inputDeco('Expense title (e.g. Grocery)'),
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amtCtrl,
              decoration: _inputDeco('Amount (₹)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Save Expense',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
        fillColor: AppTheme.backgroundLight,
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.borderLight, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.borderLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppTheme.primaryPurple, width: 2.0),
        ),
      );
}

// ─── Summary Widgets ──────────────────────────────────────────────────────

class _SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlySpendingChart extends StatelessWidget {
  final List<ExpenseModel> expenses;

  const _MonthlySpendingChart({required this.expenses});

  @override
  Widget build(BuildContext context) {
    // Group expenses by day (last 7 days)
    final now = DateTime.now();
    final Map<int, double> dailyTotals = {};
    for (int i = 6; i >= 0; i--) {
      dailyTotals[i] = 0.0;
    }
    for (final e in expenses) {
      final diff = now.difference(e.date).inDays;
      if (diff >= 0 && diff <= 6) {
        dailyTotals[diff] = (dailyTotals[diff] ?? 0) + e.amount;
      }
    }

    final maxVal =
        dailyTotals.values.fold(0.0, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 7 Days',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final dayIdx = 6 - i;
                final val = dailyTotals[dayIdx] ?? 0.0;
                final ratio = maxVal > 0 ? val / maxVal : 0.0;
                final height = math.max(8.0, ratio * 80.0);
                final dt = now.subtract(Duration(days: dayIdx));
                const days = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (val > 0)
                          Text(
                            '₹${val.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: AppTheme.primaryPurple,
                                fontSize: 8,
                                fontWeight: FontWeight.w700),
                          ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          height: height,
                          decoration: BoxDecoration(
                            gradient: val > 0
                                ? AppTheme.accentGradient
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFFE5E7EB),
                                      Color(0xFFE5E7EB)
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          days[dt.weekday % 7],
                          style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseBreakdownCard extends StatelessWidget {
  final List<ExpenseModel> expenses;

  const _ExpenseBreakdownCard({required this.expenses});

  @override
  Widget build(BuildContext context) {
    // Category totals
    final Map<String, double> cats = {};
    for (final e in expenses) {
      cats[e.category] = (cats[e.category] ?? 0) + e.amount;
    }
    final total = cats.values.fold(0.0, (s, v) => s + v);
    final sorted = cats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expense Breakdown',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ...sorted.map((e) {
            final pct = total > 0 ? e.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '₹${e.value.toStringAsFixed(0)}  ${(pct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppTheme.borderLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryPurple),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Balance Row ──────────────────────────────────────────────────────────

class _BalanceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isPositive;
  final bool isCurrentUser;

  const _BalanceRow({
    required this.label,
    required this.amount,
    required this.isPositive,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isPositive ? AppTheme.successGreen : AppTheme.errorRed;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isCurrentUser ? 'You' : label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            isPositive
                ? 'gets ₹${amount.abs().toStringAsFixed(0)}'
                : 'owes ₹${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Floating Emoji (animation) ───────────────────────────────────────────

class _FloatingEmoji extends StatefulWidget {
  final String emoji;
  final double size;
  final int delay;

  const _FloatingEmoji(
      {required this.emoji, required this.size, required this.delay});

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: -6, end: 6)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
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
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Text(widget.emoji,
            style: TextStyle(fontSize: widget.size)),
      ),
    );
  }
}

// ─── Skeleton Box ─────────────────────────────────────────────────────────

class _SkeletonBox extends StatefulWidget {
  final double height;
  final double borderRadius;

  const _SkeletonBox({required this.height, required this.borderRadius});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
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
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
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

// ─── Wave Painter ─────────────────────────────────────────────────────────

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(size.width * 0.5, size.height)
      ..quadraticBezierTo(
          size.width * 0.7, size.height * 0.2, size.width, size.height * 0.4)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path1, paint);

    final path2 = Path()
      ..moveTo(size.width * 0.4, size.height)
      ..quadraticBezierTo(
          size.width * 0.6, size.height * 0.55, size.width, size.height * 0.7)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => false;
}
