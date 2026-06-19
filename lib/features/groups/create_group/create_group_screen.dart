// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/group_model.dart';
import '../../../providers/group_detail_provider.dart';
import '../group_details/group_details_screen.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  String? _selectedType;
  String? _selectedIcon;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty && _selectedType != null;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameController.dispose();
    _nameFocus.dispose();
    ref.read(createGroupProvider.notifier).reset();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedType == null) return;
    _nameFocus.unfocus();
    HapticFeedback.mediumImpact();

    await ref.read(createGroupProvider.notifier).createGroup(
          groupName: _nameController.text.trim(),
          groupType: _selectedType!,
          groupIcon: _selectedIcon!,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createGroupProvider);

    ref.listen<CreateGroupState>(createGroupProvider, (_, next) {
      if (next is CreateGroupSuccess) {
        HapticFeedback.lightImpact();
        Navigator.of(context).pushReplacement(
          _buildPageRoute(
            GroupDetailsScreen(
              groupId: next.groupId,
              groupName: next.group.groupName,
              groupIcon: next.group.groupIcon,
            ),
          ),
        );
      } else if (next is CreateGroupFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });

    final isLoading = state is CreateGroupLoading;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(theme),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),
                      _buildGroupNameField(),
                      const SizedBox(height: 28),
                      _buildGroupTypeSection(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _buildBottomButton(isLoading),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: AppTheme.backgroundLight,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.borderLight, width: 1.5),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.textPrimary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      title: Text(
        'Create a Group',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: AppTheme.textPrimary,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Split expenses\n',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              TextSpan(
                text: 'together effortlessly.',
                style: TextStyle(
                  color: AppTheme.primaryPurple,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Name your group and choose what kind it is.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GROUP NAME',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _nameController,
          focusNode: _nameFocus,
          maxLength: 40,
          inputFormatters: [LengthLimitingTextInputFormatter(40)],
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'Enter group name',
            hintStyle: const TextStyle(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.only(left: 14, right: 10),
              child: Text(
                _selectedIcon ?? '👥',
                style: const TextStyle(fontSize: 22),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 52, minHeight: 52),
            counterText: '',
            fillColor: Colors.white,
            filled: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: AppTheme.borderLight, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                  color: AppTheme.primaryPurple, width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: AppTheme.errorRed, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: AppTheme.errorRed, width: 2.0),
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Group name is required.';
            }
            if (v.trim().length < 2) {
              return 'Name must be at least 2 characters.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildGroupTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GROUP TYPE',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose the category that best fits your group.',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 500;
            final cols = isTablet ? 4 : 4;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
              itemCount: GroupTypeOption.all.length,
              itemBuilder: (context, index) {
                final option = GroupTypeOption.all[index];
                final isSelected = _selectedType == option.type;
                return _GroupTypeCard(
                  option: option,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedType = option.type;
                      _selectedIcon = option.icon;
                    });
                  },
                );
              },
            );
          },
        ),
        if (_selectedType == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Please select a group type to continue.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomButton(bool isLoading) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: AnimatedOpacity(
        opacity: _canSubmit ? 1.0 : 0.55,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          height: 64,
          decoration: BoxDecoration(
            gradient: _canSubmit
                ? AppTheme.accentGradient
                : const LinearGradient(
                    colors: [Color(0xFFB0A8FF), Color(0xFF9B94FF)]),
            borderRadius: BorderRadius.circular(32),
            boxShadow: _canSubmit
                ? [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withOpacity(0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: ElevatedButton(
            onPressed: (isLoading || !_canSubmit) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Create Group',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  PageRouteBuilder _buildPageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return FadeTransition(
            opacity: fade, child: SlideTransition(position: slide, child: child));
      },
      transitionDuration: const Duration(milliseconds: 380),
    );
  }
}

// ─── Group Type Card ──────────────────────────────────────────────────────

class _GroupTypeCard extends StatefulWidget {
  final GroupTypeOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupTypeCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_GroupTypeCard> createState() => _GroupTypeCardState();
}

class _GroupTypeCardState extends State<_GroupTypeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.primaryPurple.withOpacity(0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.primaryPurple
                  : AppTheme.borderLight,
              width: widget.isSelected ? 2.0 : 1.5,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppTheme.primaryPurple.withOpacity(0.12)
                      : AppTheme.backgroundLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.option.icon,
                    style: TextStyle(
                        fontSize: widget.isSelected ? 24 : 22),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.option.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.isSelected
                      ? AppTheme.primaryPurple
                      : AppTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: widget.isSelected
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
