// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/onboarding_slider.dart';
import 'widgets/onboarding_buttons.dart';
import 'widgets/page_indicator.dart';

/// The onboarding screen hosting the auto-sliding slider.
/// Features touch gesture detection to pause auto-sliding, returning to standard
/// sliding cycles once the user completes their manual gesture.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _sliderTimer;

  // Onboarding Slides Content Definition
  final List<OnboardingSlideData> _slides = const [
    OnboardingSlideData(
      title: "Split Expenses Intuitively",
      subtitle:
          "Log household expenses, bills, and groceries in seconds. No more awkward roommate math.",
      imagePath: "assets/images/onboarding_1.png",
      fallbackIcon: Icons.receipt_long_rounded,
    ),
    OnboardingSlideData(
      title: "Track Shared Ledger",
      subtitle:
          "Stay synchronized with roommates. See exactly who owes what at a glance, stress-free.",
      imagePath: "assets/images/onboarding_2.png",
      fallbackIcon: Icons.account_balance_wallet_rounded,
    ),
    OnboardingSlideData(
      title: "Settle Up Instantly",
      subtitle:
          "Settle tabs easily with secure ledger logs. Keep roommate relationships smooth.",
      imagePath: "assets/images/onboarding_3.png",
      fallbackIcon: Icons.handshake_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _stopAutoSlide();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _sliderTimer?.cancel();
    _sliderTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final int nextPage = (_currentPage + 1) % _slides.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _stopAutoSlide() {
    _sliderTimer?.cancel();
    _sliderTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Stack(
        children: [
          // 1. Full-screen sliding Onboarding Carousel (pauses auto-slide on touch)
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification is ScrollStartNotification) {
                  if (notification.dragDetails != null) {
                    _stopAutoSlide();
                  }
                } else if (notification is ScrollEndNotification) {
                  _startAutoSlide();
                }
                return false;
              },
              child: OnboardingSlider(
                controller: _pageController,
                slides: _slides,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
              ),
            ),
          ),

          // 2. Fixed Bottom Controls Overlay (Indicators + Buttons)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.backgroundLight.withOpacity(0.0),
                    AppTheme.backgroundLight.withOpacity(0.85),
                    AppTheme.backgroundLight,
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    // Animated Dot Indicators
                    PageIndicator(
                      currentIndex: _currentPage,
                      itemCount: _slides.length,
                    ),
                    const SizedBox(height: 20),
                    // Fixed Action Buttons
                    const OnboardingButtons(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
