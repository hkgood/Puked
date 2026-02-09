import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _pageCount = 6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final List<Map<String, String>> onboardingData = [
      {
        'image': 'assets/images/E00.png',
        'text': l10n.onboarding_welcome,
      },
      {
        'image': 'assets/images/E01.png',
        'text': l10n.onboarding_step1,
      },
      {
        'image': 'assets/images/E02.png',
        'text': l10n.onboarding_step2,
      },
      {
        'image': 'assets/images/E03.png',
        'text': l10n.onboarding_step3,
      },
      {
        'image': 'assets/images/E04.png',
        'text': l10n.onboarding_step4,
      },
      {
        'image': 'assets/images/E05.png',
        'text': l10n.onboarding_step5,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pageCount,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      Image.asset(
                        onboardingData[index]['image']!,
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                      ),
                      const SizedBox(height: 40),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Text(
                          onboardingData[index]['text']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const Spacer(flex: 2),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  SizedBox(
                    height: 56,
                    child: _currentPage == _pageCount - 1
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: ElevatedButton(
                              onPressed: () {
                                ref
                                    .read(settingsProvider.notifier)
                                    .completeOnboarding();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1C1C1E),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                l10n.onboarding_start,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 32),
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pageCount,
                    effect: const WormEffect(
                      dotColor: Color(0xFFE5E5EA),
                      activeDotColor: Color(0xFF1C1C1E),
                      dotHeight: 10,
                      dotWidth: 10,
                      spacing: 12,
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
