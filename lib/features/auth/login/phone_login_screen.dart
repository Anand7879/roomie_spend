import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../otp/otp_verification_screen.dart';

/// The screen where users input their country code and mobile number to request an OTP.
class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  String _selectedCountryCode = "+91";
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submitPhoneNumber() {
    setState(() {
      _errorMessage = null;
    });

    final phoneText = _phoneController.text.trim();

    if (phoneText.isEmpty) {
      setState(() {
        _errorMessage = "Mobile number cannot be empty.";
      });
      return;
    }

    final numDigits = phoneText.replaceAll(RegExp(r'\D'), '').length;
    if (numDigits < 8 || numDigits > 12) {
      setState(() {
        _errorMessage = "Please enter a valid mobile number.";
      });
      return;
    }

    final fullPhoneNumber = "$_selectedCountryCode$phoneText";
    ref.read(authStateNotifierProvider.notifier).sendOtp(fullPhoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateNotifierProvider);
    final theme = Theme.of(context);

    // Listen for state changes to navigate
    ref.listen<AuthState>(authStateNotifierProvider, (previous, next) {
      if (next is AuthCodeSent) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const OtpVerificationScreen(),
          ),
        );
      } else if (next is AuthFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    });

    final isLoading = authState is AuthLoading;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderLight, width: 1.5),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                "Welcome to RoomieSpend",
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Smart expense sharing for roommates.",
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              const Text(
                "ENTER MOBILE NUMBER",
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _errorMessage != null
                        ? AppTheme.errorRed
                        : AppTheme.borderLight,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    CountryCodePicker(
                      onChanged: (code) {
                        setState(() {
                          _selectedCountryCode = code.dialCode ?? "+91";
                        });
                      },
                      initialSelection: 'IN',
                      favorite: const ['+91', '+1', '+44'],
                      showCountryOnly: false,
                      showOnlyCountryWhenClosed: false,
                      alignLeft: false,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      dialogTextStyle: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      height: 30,
                      width: 1.5,
                      color: AppTheme.borderLight,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: "Mobile number",
                          hintStyle: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.errorRed,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 35),

              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withOpacity(0.24),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitPhoneNumber,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          "Request OTP",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
