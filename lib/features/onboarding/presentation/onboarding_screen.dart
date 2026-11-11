import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/storage/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/safety_banner.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'tag': 'EAII AUTONOMOUS PLATFORM',
      'title': 'Autonomous Fleet Oversight',
      'subtitle':
          'Monitor real-time positions, cleaning coverage, battery telemetry, and waste container capacity with precision.',
      'icon': Icons.precision_manufacturing_outlined,
    },
    {
      'tag': 'PRECISION ROBOTICS',
      'title': 'Intelligent Zone Cleaning',
      'subtitle':
          'Command autonomous robots to execute targeted multi-zone cleaning missions, inspect cleanliness, and dock automatically.',
      'icon': Icons.map_outlined,
    },
    {
      'tag': 'SAFETY PROTOCOL',
      'title': 'Operational Safety & Compliance',
      'subtitle':
          'Safety-first autonomous execution. Hardware collision controllers are local and authoritative. Always supervise working zones.',
      'icon': Icons.shield_outlined,
    },
  ];

  void _finishOnboarding() async {
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setOnboardingCompleted(true);
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header with Institution branding and Skip action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.smart_toy_rounded,
                          color: AppColors.techOrange,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'EAII ROBOTICS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryNavy.withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            page['icon'] as IconData,
                            size: 50,
                            color: AppColors.techOrange,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.techOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            page['tag'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.techOrange,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          page['subtitle'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        if (index == 2) ...[
                          const SizedBox(height: 24),
                          const SafetyBanner(compact: true),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicator Dots & Next / Get Started Action
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppColors.techOrange
                              : AppColors.lightBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.techOrange,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size(140, 48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _finishOnboarding();
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _pages.length - 1
                              ? 'Enter Console'
                              : 'Next',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
