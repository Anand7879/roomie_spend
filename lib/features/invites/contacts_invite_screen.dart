import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/invite_provider.dart';

class ContactsInviteScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final String inviteCode;

  const ContactsInviteScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.inviteCode,
  });

  @override
  ConsumerState<ContactsInviteScreen> createState() => _ContactsInviteScreenState();
}

class _ContactsInviteScreenState extends ConsumerState<ContactsInviteScreen> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  Set<String> _selectedContacts = {};
  bool _isLoading = true;
  bool _permissionDenied = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndLoadContacts() async {
    setState(() => _isLoading = true);
    
    final status = await Permission.contacts.request();
    
    if (status.isGranted) {
      await _loadContacts();
    } else if (status.isDenied || status.isPermanentlyDenied) {
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
    }
  }

  Future<void> _loadContacts() async {
    try {
      if (await FlutterContacts.requestPermission()) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );
        
        // Filter contacts with at least one phone number
        final validContacts = contacts.where((c) => c.phones.isNotEmpty).toList();
        
        // Sort alphabetically
        validContacts.sort((a, b) => (a.displayName).compareTo(b.displayName));
        
        setState(() {
          _contacts = validContacts;
          _filteredContacts = validContacts;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _permissionDenied = true;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load contacts: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((contact) {
          final name = contact.displayName.toLowerCase();
          final phones = contact.phones.map((p) => p.number.toLowerCase()).join(' ');
          return name.contains(query) || phones.contains(query);
        }).toList();
      }
    });
  }

  void _toggleContact(String contactId) {
    setState(() {
      if (_selectedContacts.contains(contactId)) {
        _selectedContacts.remove(contactId);
      } else {
        _selectedContacts.add(contactId);
      }
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _sendInvites() async {
    if (_selectedContacts.isEmpty) return;
    
    HapticFeedback.mediumImpact();
    
    final service = ref.read(inviteServiceProvider);
    final shareText = service.generateShareText(widget.inviteCode, widget.groupName);
    
    // For now, we'll use SMS share. In a production app, you would:
    // 1. Check if contacts are RoomieSpend users (via phone lookup in Firestore)
    // 2. Send in-app notification if they are users
    // 3. Send SMS if they are not users
    
    await Share.share(
      shareText,
      subject: 'Join my RoomieSpend group',
    );
    
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite sent to ${_selectedContacts.length} contact(s)'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _selectedContacts.isNotEmpty ? _buildBottomBar() : null,
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
        'Invite from Contacts',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_permissionDenied) {
      return _buildPermissionDenied();
    }

    if (_contacts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts_outlined, size: 64, color: AppTheme.textMuted),
            SizedBox(height: 16),
            Text(
              'No contacts found',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildContactsList()),
      ],
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 24),
            const Text(
              'Contacts Permission Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'To invite friends from your contacts, please grant access to your contacts in Settings.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search contacts...',
          prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
          filled: true,
          fillColor: AppTheme.backgroundLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    if (_filteredContacts.isEmpty) {
      return const Center(
        child: Text(
          'No contacts match your search',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredContacts.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final contact = _filteredContacts[index];
        final isSelected = _selectedContacts.contains(contact.id);
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.lightPurpleContainer : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryPurple : AppTheme.borderLight,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ListTile(
            onTap: () => _toggleContact(contact.id),
            leading: CircleAvatar(
              backgroundColor: isSelected ? AppTheme.primaryPurple : AppTheme.lightPurpleContainer,
              child: Text(
                contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.primaryPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(
              contact.displayName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              phone,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            trailing: isSelected
                ? const Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryPurple,
                  )
                : const Icon(
                    Icons.circle_outlined,
                    color: AppTheme.textMuted,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _sendInvites,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Send Invite to ${_selectedContacts.length} contact(s)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
