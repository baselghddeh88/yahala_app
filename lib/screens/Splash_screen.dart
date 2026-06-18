import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants.dart';
import '../services/app_settings.dart';
import '../services/notification_service.dart';
import 'auth_choice_screen.dart';
import 'home_screen.dart';
import 'language_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;

      final openedAd = await NotificationService.openPendingAdIfAny();

      if (!mounted ||
          openedAd ||
          NotificationService.openedAdFromNotification) {
        return;
      }

      final settings = await AppSettings.load();
      if (!mounted) return;

      if (!settings.languageChosen) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LanguageScreen()),
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => user == null
              ? AuthChoiceScreen(
                  isArabic: settings.isArabic,
                  isDark: settings.isDark,
                )
              : HomeScreen(
                  initialArabic: settings.isArabic,
                  initialDark: settings.isDark,
                ),
        ),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        NotificationService.openPendingAdIfAny();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: yahalaLightBg,
      body: Center(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 28,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(22),
                    child: _SplashLogo(),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'يا هلا',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: yahalaGreen,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'جريدة العرب في المهجر',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: yahalaGold,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return yahalaLogo(width: 150);
  }
}
