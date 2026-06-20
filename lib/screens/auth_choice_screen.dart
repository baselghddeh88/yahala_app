import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants.dart';
import '../services/app_settings.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'legal_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthChoiceScreen extends StatelessWidget {
  final bool isArabic;
  final bool isDark;

  const AuthChoiceScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: yahalaPageBg(isDark),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: yahalaCardBg(isDark),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.25 : 0.08,
                              ),
                              blurRadius: 30,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: yahalaLogo(width: 132),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        t('أهلاً وسهلاً في يا هلا', 'Welcome to Yahala'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: yahalaText(isDark),
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t(
                          'إعلانات، خدمات، فرص، وأخبار الجالية العربية في مكان واحد.',
                          'Ads, services, opportunities, and community updates in one place.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: yahalaMutedText(isDark),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _primaryButton(
                  text: currentUser == null
                      ? t('تسجيل الدخول', 'Login')
                      : t('فتح حسابي', 'Open my account'),
                  color: yahalaGreen,
                  onPressed: () async {
                    await AppSettings.save(isArabic: isArabic, isDark: isDark);

                    if (!context.mounted) return;

                    if (currentUser != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HomeScreen(
                            initialArabic: isArabic,
                            initialDark: isDark,
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LoginScreen(isArabic: isArabic, isDark: isDark),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (currentUser == null) ...[
                  TextButton.icon(
                    onPressed: () => _showResetPasswordDialog(context),
                    icon: Icon(
                      Icons.lock_reset,
                      color: isDark ? Colors.white70 : yahalaGreen,
                    ),
                    label: Text(
                      t('نسيت كلمة المرور؟', 'Forgot password?'),
                      style: TextStyle(
                        color: isDark ? Colors.white : yahalaGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _primaryButton(
                  text: t('إنشاء حساب', 'Create account'),
                  color: yahalaGold,
                  onPressed: currentUser != null
                      ? null
                      : () async {
                          await AppSettings.save(
                            isArabic: isArabic,
                            isDark: isDark,
                          );

                          if (!context.mounted) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegisterScreen(
                                isArabic: isArabic,
                                isDark: isDark,
                              ),
                            ),
                          );
                        },
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () async {
                    await AppSettings.save(isArabic: isArabic, isDark: isDark);

                    if (!context.mounted) return;

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HomeScreen(
                          initialArabic: isArabic,
                          initialDark: isDark,
                        ),
                      ),
                    );

                    Future.delayed(const Duration(milliseconds: 500), () {
                      NotificationService.openPendingAdIfAny();
                    });
                  },
                  child: Text(
                    t('المتابعة كزائر', 'Continue as guest'),
                    style: TextStyle(
                      color: isDark ? Colors.white : yahalaGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LegalScreen(isArabic: isArabic, isDark: isDark),
                      ),
                    );
                  },
                  child: Text(
                    t('الشروط والخصوصية', 'Terms & Privacy'),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : yahalaMutedText(false),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String text,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Future<void> _showResetPasswordDialog(BuildContext context) async {
    final emailController = TextEditingController();

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Text(t('استعادة كلمة المرور', 'Reset password')),
            content: TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: t('اكتب بريدك الإلكتروني', 'Enter your email'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(t('إلغاء', 'Cancel')),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, emailController.text.trim()),
                child: Text(t('إرسال', 'Send')),
              ),
            ],
          ),
        );
      },
    );

    emailController.dispose();

    if (email == null || email.isEmpty) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'تم إرسال رابط تغيير كلمة المرور إلى بريدك',
              'Password reset link sent to your email',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'تأكد من البريد وحاول مرة ثانية',
              'Check the email and try again',
            ),
          ),
        ),
      );
    }
  }
}
