import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../profile_setup/profile_setup_screen.dart';
import '../../dashboard/home_screen.dart';

/// Screen where users verify their identity by entering the 6-digit OTP code.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  late PinInputController _pinController;
  Timer? _countdownTimer;
  int _timerSeconds = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _pinController = PinInputController();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _timerSeconds = 30;
      _canResend = false;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      } else {
        setState(() {
          _timerSeconds--;
        });
      }
    });
  }

  void _triggerResend() {
    final authState = ref.read(authStateNotifierProvider);
    if (authState is AuthCodeSent) {
      ref.read(authStateNotifierProvider.notifier).sendOtp(authState.phoneNumber);
      _startCountdown();
    }
  }

  void _verifyOtp(String code) {
    if (code.length == 6) {
      ref.read(authStateNotifierProvider.notifier).verifyOtp(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateNotifierProvider);
    final theme = Theme.of(context);

    // Get phone number from state
    String displayPhone = "";
    if (authState is AuthCodeSent) {
      displayPhone = authState.phoneNumber;
    } else if (authState is AuthProfileIncomplete) {
      displayPhone = authState.phone;
    }

    // Listen for state changes to navigate
    ref.listen<AuthState>(authStateNotifierProvider, (previous, next) {
      if (next is AuthProfileIncomplete) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const ProfileSetupScreen(),
          ),
          (route) => false,
        );
      } else if (next is AuthAuthenticated) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
          (route) => false,
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
                "Verify Code",
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Enter the 6-digit OTP verification code sent to $displayPhone.",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // PIN Code Fields using the v9.x MaterialPinField API
              MaterialPinField(
                length: 6,
                pinController: _pinController,
                keyboardType: TextInputType.number,
                autoFocus: true,
                obscureText: false,
                theme: MaterialPinTheme(
                  shape: MaterialPinShape.outlined,
                  borderRadius: BorderRadius.circular(12),
                  cellSize: const Size(46, 52),
                  spacing: 8,
                  fillColor: Colors.white,
                  focusedFillColor: Colors.white,
                  filledFillColor: Colors.white,
                  borderColor: AppTheme.borderLight,
                  focusedBorderColor: AppTheme.primaryPurple,
                  filledBorderColor: AppTheme.primaryPurple,
                  borderWidth: 1.5,
                  focusedBorderWidth: 2.0,
                  textStyle: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  cursorColor: AppTheme.primaryPurple,
                  entryAnimation: MaterialPinAnimation.fade,
                ),
                onChanged: (value) {},
                onCompleted: _verifyOtp,
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive the code? ",
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  _canResend
                      ? GestureDetector(
                          onTap: isLoading ? null : _triggerResend,
                          child: const Text(
                            "Resend OTP",
                            style: TextStyle(
                              color: AppTheme.primaryPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : Text(
                          "Resend in ${_timerSeconds}s",
                          style: const TextStyle(
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 40),

              if (isLoading)
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        color: AppTheme.primaryPurple,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Verifying security code...",
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
