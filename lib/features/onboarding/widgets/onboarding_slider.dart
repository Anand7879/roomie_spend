// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Represents the content layout for a single onboarding slide.
class OnboardingSlideData {
  final String title;
  final String subtitle;
  final String imagePath;
  final IconData fallbackIcon;

  const OnboardingSlideData({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.fallbackIcon,
  });
}

/// A carousel slider widget displaying onboarding pages.
/// Focuses on displaying the image in full screen (with bottom constraint for buttons)
/// and removes extra text details since text is baked into the slides.
class OnboardingSlider extends StatelessWidget {
  final PageController controller;
  final List<OnboardingSlideData> slides;
  final Function(int) onPageChanged;

  const OnboardingSlider({
    super.key,
    required this.controller,
    required this.slides,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      itemCount: slides.length,
      onPageChanged: onPageChanged,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final slide = slides[index];
        return Padding(
          // Leave exactly 220px bottom clearance to prevent image overlap with buttons and indicators.
          // This keeps the baked-in illustration text perfectly readable in the middle safe area.
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 220),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              slide.imagePath,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) {
                // Vector-style fallback in case assets are not loaded yet
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.lightPurpleContainer,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.borderLight, width: 1.5),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryPurple.withOpacity(0.05),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -30,
                        bottom: -30,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.secondaryViolet.withOpacity(0.05),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryPurple.withOpacity(0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  )
                                ],
                              ),
                              child: Icon(
                                slide.fallbackIcon,
                                color: AppTheme.primaryPurple,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              slide.subtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
