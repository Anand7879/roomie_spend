import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/invite_provider.dart';
import 'scan_qr_screen.dart';
import 'show_qr_screen.dart';
import 'contacts_invite_screen.dart';
import 'join_by_code_screen.dart';

class InviteFriendsScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final String groupIcon;

  const InviteFriendsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.groupIcon,
  });

  @override
  ConsumerState<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends ConsumerState<InviteFriendsScreen>
    with SingleTickerProviderStateMixin {
  String? _inviteCode;
  bool _isLoadingCode = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadInviteCode();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadInviteCode() async {
    setState(() => _isLoadingCode = true);
    
    // Try to get existing invite code
    String? existingCode = await ref.read(inviteProvider.notifier).getActiveInviteCode(widget.groupId);
    
    if (existingCode != null) {
      setState(() {
        _inviteCode = existingCode;
        _isLoadingCode = false;
      });
    } else {
      // Generate new invite code
      await ref.read(inviteProvider.notifier).generateInviteCode(widget.groupId);
    }
  }

  Future<void> _handleScanQR() async {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanQRScreen()),
    );
  }

  Future<void> _handleShowQR() async {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShowQRScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
          groupIcon: widget.groupIcon,
        ),
      ),
    );
  }

  Future<void> _handleShare() async {
    if (_inviteCode == null || _isLoadingCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading invite code...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    
    HapticFeedback.lightImpact();
    final service = ref.read(inviteServiceProvider);
    final shareText = service.generateShareText(_inviteCode!, widget.groupName);
    
    await Share.share(
      shareText,
      subject: 'Join my RoomieSpend group',
    );
  }

  Future<void> _handleContacts() async {
    if (_inviteCode == null || _isLoadingCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading invite code...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactsInviteScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
          inviteCode: _inviteCode!,
        ),
      ),
    );
  }

  Future<void> _handleJoinByCode() async {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JoinByCodeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<InviteState>(inviteProvider, (_, next) {
      if (next is InviteCodeGenerated) {
        setState(() {
          _inviteCode = next.inviteCode;
          _isLoadingCode = false;
        });
      } else if (next is InviteFailure) {
        setState(() => _isLoadingCode = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildInviteOptions(),
              const SizedBox(height: 32),
              _buildDivider(),
              const SizedBox(height: 32),
              _buildJoinSection(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
        'Invite Friends',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group Info
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    widget.groupIcon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Invite friends to join',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        const Text(
          'Choose an invite method',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInviteOptions() {
    return Column(
      children: [
        _InviteOptionCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Show QR Code',
          subtitle: 'Let others scan your QR code',
          gradient: AppTheme.accentGradient,
          onTap: _handleShowQR,
        ),
        const SizedBox(height: 12),
        _InviteOptionCard(
          icon: Icons.share_rounded,
          title: 'Share Invite Link',
          subtitle: 'Share via WhatsApp, SMS, or social media',
          gradient: const LinearGradient(
            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
          ),
          onTap: _handleShare,
          isLoading: _isLoadingCode,
        ),
        const SizedBox(height: 12),
        _InviteOptionCard(
          icon: Icons.contacts_rounded,
          title: 'Add from Contacts',
          subtitle: 'Invite friends from your phone contacts',
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          ),
          onTap: _handleContacts,
          isLoading: _isLoadingCode,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppTheme.borderLight)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppTheme.borderLight)),
      ],
    );
  }

  Widget _buildJoinSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Join a group',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        _InviteOptionCard(
          icon: Icons.qr_code_scanner,
          title: 'Scan QR Code',
          subtitle: 'Scan a group QR code to join',
          gradient: const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
          ),
          onTap: _handleScanQR,
        ),
        const SizedBox(height: 12),
        _InviteOptionCard(
          icon: Icons.vpn_key_rounded,
          title: 'Enter Invite Code',
          subtitle: 'Join using a group invite code',
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          ),
          onTap: _handleJoinByCode,
        ),
      ],
    );
  }
}

class _InviteOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final bool isLoading;

  const _InviteOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : Icon(
                        icon,
                        color: Colors.white,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
