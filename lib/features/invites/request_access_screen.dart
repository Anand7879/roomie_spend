import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/group_invite_model.dart';
import '../../models/join_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_detail_provider.dart';
import '../../providers/invite_provider.dart';
import '../groups/group_details/group_details_screen.dart';

class RequestAccessScreen extends ConsumerStatefulWidget {
  final GroupInviteModel invite;
  const RequestAccessScreen({super.key, required this.invite});

  @override
  ConsumerState<RequestAccessScreen> createState() => _RequestAccessScreenState();
}

class _RequestAccessScreenState extends ConsumerState<RequestAccessScreen> {
  bool _isProcessing = false;

  Future<void> _handleRequestAccess(String groupName, String adminUid) async {
    final authState = ref.read(authStateNotifierProvider);
    if (authState is! AuthAuthenticated) return;
    
    final user = authState.user;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final service = ref.read(inviteServiceProvider);
      await service.createJoinRequest(
        groupId: widget.invite.groupId,
        groupName: groupName,
        requestedBy: user.uid,
        requestedUserName: user.name,
        requestedUserPhoto: user.avatar,
        requestedPhone: user.phone,
        adminUid: adminUid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access request sent successfully!'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request access: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleRequestAgain(String requestId) async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final service = ref.read(inviteServiceProvider);
      await service.reSubmitJoinRequest(requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request re-submitted successfully!'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to re-submit request: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateNotifierProvider);
    if (authState is! AuthAuthenticated) {
      return const Scaffold(
        body: Center(child: Text('Please log in first.')),
      );
    }
    final user = authState.user;

    // Listen to group details
    final groupAsync = ref.watch(groupDetailProvider(widget.invite.groupId));

    // Stream status of join request for this group and user
    final service = ref.read(inviteServiceProvider);
    return StreamBuilder<JoinRequestModel?>(
      stream: service.watchRequestStatus(widget.invite.groupId, user.uid),
      builder: (context, snapshot) {
        final request = snapshot.data;

        // Auto-navigate to Group Details if approved
        if (request != null && request.status == 'approved') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => GroupDetailsScreen(
                    groupId: widget.invite.groupId,
                    groupName: request.groupName,
                    groupIcon: '', // Will fetch dynamically
                  ),
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Joined group successfully!'),
                  backgroundColor: AppTheme.successGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          });
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryPurple),
            ),
          );
        }

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
              'Join Group',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          body: groupAsync.when(
            data: (group) {
              if (group == null) {
                return const Center(child: Text('Group not found or no longer exists.'));
              }

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Group Icon Hero
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppTheme.lightPurpleContainer,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            group.groupIcon,
                            style: const TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        group.groupName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Status Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.borderLight, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              _getTitle(request?.status),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _getDescription(request?.status),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Action Button
                      _buildButton(request, group.groupName, group.createdBy),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryPurple),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err', style: const TextStyle(color: AppTheme.errorRed)),
            ),
          ),
        );
      },
    );
  }

  String _getTitle(String? status) {
    if (status == 'pending') return 'Request Pending';
    if (status == 'denied') return 'Request Declined';
    return 'Request Access to the Group';
  }

  String _getDescription(String? status) {
    if (status == 'pending') {
      return 'Your access request has been sent to the group admin. You will be added automatically once approved.';
    }
    if (status == 'denied') {
      return 'Your request to join the group was declined. You can try requesting access again or ask the admin for a new invite.';
    }
    return 'You are not added to the group yet. Tap below to request access to the group.';
  }

  Widget _buildButton(JoinRequestModel? request, String groupName, String adminUid) {
    final status = request?.status;
    final isPending = status == 'pending';
    final isDenied = status == 'denied';

    final text = isPending
        ? 'Request Pending'
        : isDenied
            ? 'Request Again'
            : 'Request Access';

    final color = isPending
        ? AppTheme.textMuted
        : isDenied
            ? const Color(0xFF3B82F6) // blue for request again
            : AppTheme.primaryPurple;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isProcessing || isPending
            ? null
            : () {
                if (isDenied) {
                  _handleRequestAgain(request!.requestId);
                } else {
                  _handleRequestAccess(groupName, adminUid);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.borderLight,
          disabledForegroundColor: AppTheme.textMuted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
