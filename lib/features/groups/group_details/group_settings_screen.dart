import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/group_model.dart';
import '../../../models/join_request_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/invite_provider.dart';

class GroupSettingsScreen extends ConsumerWidget {
  final GroupModel group;
  const GroupSettingsScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateNotifierProvider);
    final currentUid = authState is AuthAuthenticated ? authState.user.uid : '';
    final isAdmin = group.createdBy == currentUid;

    final requestsAsync = ref.watch(pendingGroupRequestsProvider(group.id));
    final membersAsync = ref.watch(groupMembersProvider(group.id));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: AppTheme.backgroundLight,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderLight, width: 1.5),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text(
          'Group Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Section 1: Pending Join Requests (Visible only to Group Admin/Creator)
          if (isAdmin) ...[
            const Text(
              'Pending Join Requests',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            requestsAsync.when(
              data: (requests) {
                if (requests.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderLight, width: 1),
                    ),
                    child: const Center(
                      child: Text(
                        'No pending join requests.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    return _PendingRequestCard(request: requests[i], group: group);
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                ),
              ),
              error: (err, _) => Center(
                child: Text('Error: $err', style: const TextStyle(color: AppTheme.errorRed)),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // Section 2: Group Members
          const Text(
            'Group Members',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          membersAsync.when(
            data: (members) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderLight, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderLight),
                  itemBuilder: (context, i) {
                    final m = members[i];
                    final isMemberAdmin = group.createdBy == m.userId;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.borderLight, width: 1),
                        ),
                        child: Center(
                          child: Text(
                            m.userAvatar.isNotEmpty ? m.userAvatar : '👤',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      title: Text(
                        m.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: m.userPhone.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                m.userPhone,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            )
                          : null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMemberAdmin
                              ? AppTheme.lightPurpleContainer
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isMemberAdmin ? 'Creator' : 'Member',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isMemberAdmin
                                ? AppTheme.primaryPurple
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: AppTheme.primaryPurple),
              ),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err', style: const TextStyle(color: AppTheme.errorRed)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRequestCard extends ConsumerStatefulWidget {
  final JoinRequestModel request;
  final GroupModel group;
  const _PendingRequestCard({required this.request, required this.group});

  @override
  ConsumerState<_PendingRequestCard> createState() => _PendingRequestCardState();
}

class _PendingRequestCardState extends ConsumerState<_PendingRequestCard> {
  bool _isApproving = false;
  bool _isDenying = false;

  Future<void> _approve() async {
    setState(() => _isApproving = true);
    final authState = ref.read(authStateNotifierProvider);
    final adminUid = authState is AuthAuthenticated ? authState.user.uid : '';
    final adminName = authState is AuthAuthenticated ? authState.user.name : '';

    final service = ref.read(inviteServiceProvider);
    final res = await service.approveJoinRequest(
      requestId: widget.request.requestId,
      adminUid: adminUid,
      adminName: adminName,
    );

    if (mounted) {
      setState(() => _isApproving = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.request.requestedUserName} approved successfully!'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${res['message']}'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deny() async {
    setState(() => _isDenying = true);
    final authState = ref.read(authStateNotifierProvider);
    final adminUid = authState is AuthAuthenticated ? authState.user.uid : '';

    final service = ref.read(inviteServiceProvider);
    final res = await service.denyJoinRequest(
      requestId: widget.request.requestId,
      adminUid: adminUid,
    );

    if (mounted) {
      setState(() => _isDenying = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.request.requestedUserName} request declined.'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${res['message']}'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderLight, width: 1),
                ),
                child: Center(
                  child: Text(
                    req.requestedUserPhoto.isNotEmpty ? req.requestedUserPhoto : '👤',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.requestedUserName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      req.requestedPhone.isNotEmpty ? req.requestedPhone : 'No phone',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${req.requestedUserName} wants to join the group',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    onPressed: _isApproving || _isDenying ? null : _deny,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.errorRed, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      foregroundColor: AppTheme.errorRed,
                    ),
                    child: _isDenying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: AppTheme.errorRed, strokeWidth: 1.5),
                          )
                        : const Text(
                            'Deny',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: _isApproving || _isDenying ? null : _approve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isApproving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
                          )
                        : const Text(
                            'Approve',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
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
