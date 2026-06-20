import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../constants.dart';
import 'home_screen.dart';
import 'legal_screen.dart';
import '../services/app_settings.dart';
import '../services/notification_service.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class LoginScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;

  const LoginScreen({super.key, required this.isArabic, required this.isDark});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('عبّي الإيميل وكلمة السر', 'Enter email and password'),
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      await AppSettings.save(isArabic: widget.isArabic, isDark: widget.isDark);
      NotificationService.saveFcmTokenInBackground();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            initialArabic: widget.isArabic,
            initialDark: widget.isDark,
          ),
        ),
        (route) => false,
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        NotificationService.openPendingAdIfAny();
      });
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'user-not-found' || 'wrong-password' || 'invalid-credential' => t(
          'الإيميل أو كلمة السر غير صحيحة',
          'Email or password is incorrect',
        ),
        'invalid-email' => t('الإيميل غير صالح', 'Invalid email address'),
        _ => t('فشل تسجيل الدخول', 'Login failed'),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'اكتب الإيميل بالأعلى ثم اضغط نسيت كلمة المرور',
              'Enter your email above, then tap forgot password',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'أرسلنا رابط تغيير كلمة المرور إلى بريدك',
              'Password reset link sent to your email',
            ),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      final message = e.code == 'invalid-email'
          ? t('الإيميل غير صالح', 'Invalid email address')
          : t(
              'إذا كان الإيميل مسجل، سيصلك رابط تغيير كلمة المرور',
              'If the email exists, a reset link will be sent',
            );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> signInWithGoogle() async {
    if (!await _ensureLegalAccepted()) return;

    setState(() => isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        if (mounted) {
          setState(() => isLoading = false);
        }
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          if ((user.displayName ?? '').isNotEmpty) 'name': user.displayName,
          if ((user.email ?? '').isNotEmpty) 'email': user.email,
          'emailVerified': user.emailVerified,
          'authProvider': 'google',
          'acceptedTerms': true,
          'acceptedPrivacy': true,
          'legalVersion': AppSettings.legalVersion,
          'acceptedLegalAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await AppSettings.save(isArabic: widget.isArabic, isDark: widget.isDark);
      await AppSettings.saveLegalAccepted();
      NotificationService.saveFcmTokenInBackground();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            initialArabic: widget.isArabic,
            initialDark: widget.isDark,
          ),
        ),
        (route) => false,
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        NotificationService.openPendingAdIfAny();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('فشل الدخول عبر Google', 'Google sign-in failed')),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> signInWithApple() async {
    if (!await _ensureLegalAccepted()) return;

    setState(() => isLoading = true);

    try {
      final isAppleAvailable = await SignInWithApple.isAvailable();

      if (!isAppleAvailable) {
        throw SignInWithAppleNotSupportedException(
          message: t(
            'تسجيل الدخول عبر Apple غير متاح على هذا الجهاز.',
            'Apple sign-in is not available on this device.',
          ),
        );
      }

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final identityToken = appleCredential.identityToken;

      if (identityToken == null || identityToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-apple-token',
          message: t(
            'تعذر استلام رمز Apple. جرّب من جديد.',
            'Could not get Apple token. Try again.',
          ),
        );
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        oauthCredential,
      );

      final displayName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].where((part) => part != null && part.trim().isNotEmpty).join(' ');

      if (displayName.isNotEmpty) {
        await userCredential.user?.updateDisplayName(displayName);
      }

      final user = userCredential.user;

      if (user != null) {
        final fallbackName = user.displayName?.trim() ?? '';
        final name = displayName.isNotEmpty ? displayName : fallbackName;

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          if (name.isNotEmpty) 'name': name,
          if ((user.email ?? appleCredential.email)?.isNotEmpty ?? false)
            'email': user.email ?? appleCredential.email,
          'emailVerified': user.emailVerified,
          'authProvider': 'apple',
          'acceptedTerms': true,
          'acceptedPrivacy': true,
          'legalVersion': AppSettings.legalVersion,
          'acceptedLegalAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await AppSettings.save(isArabic: widget.isArabic, isDark: widget.isDark);
      await AppSettings.saveLegalAccepted();
      NotificationService.saveFcmTokenInBackground();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            initialArabic: widget.isArabic,
            initialDark: widget.isDark,
          ),
        ),
        (route) => false,
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        NotificationService.openPendingAdIfAny();
      });
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;

      if (e.code == AuthorizationErrorCode.canceled) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      _showAppleError(
        '${_appleAuthorizationMessage(e)}\n${e.code}: ${e.message}',
      );
    } on SignInWithAppleNotSupportedException catch (_) {
      if (!mounted) return;

      _showAppleError(
        t(
          'تسجيل الدخول عبر Apple غير متاح على هذا الجهاز.',
          'Apple sign-in is not available on this device.',
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showAppleError(_firebaseAppleMessage(e));
    } catch (e) {
      debugPrint('APPLE ERROR: $e');

      if (!mounted) return;

      _showAppleError(
        '${t('فشل الدخول عبر Apple', 'Apple sign-in failed')}\n$e',
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<bool> _ensureLegalAccepted() async {
    if (await AppSettings.hasAcceptedLegal()) return true;

    if (!mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: widget.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: AlertDialog(
            title: Text(t('الشروط والخصوصية', 'Terms and Privacy')),
            content: SingleChildScrollView(
              child: Text(
                t(
                  'قبل المتابعة، لازم توافق على شروط الاستخدام وسياسة الخصوصية. نستخدم بيانات الحساب والإعلانات والمحادثات والإشعارات لتشغيل التطبيق وتحسين الخدمة، والإعلانات قد تخضع للمراجعة قبل النشر.',
                  'Before continuing, please accept the Terms of Use and Privacy Policy. We use account, ads, chats, and notification data to operate and improve the app, and ads may be reviewed before publishing.',
                ),
                style: const TextStyle(height: 1.45),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    dialogContext,
                    MaterialPageRoute(
                      builder: (_) => LegalScreen(
                        isArabic: widget.isArabic,
                        isDark: widget.isDark,
                      ),
                    ),
                  );
                },
                child: Text(t('قراءة الشروط', 'Read terms')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(t('إلغاء', 'Cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(t('أوافق', 'I agree')),
              ),
            ],
          ),
        );
      },
    );

    if (accepted == true) {
      await AppSettings.saveLegalAccepted();
      return true;
    }

    return false;
  }

  void _showAppleError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 7),
      ),
    );
  }

  String _appleAuthorizationMessage(SignInWithAppleAuthorizationException e) {
    return switch (e.code) {
      AuthorizationErrorCode.failed => t(
        'Apple رفضت الطلب. تأكد أن Sign in with Apple مفعّل للتطبيق في Xcode و Apple Developer.',
        'Apple rejected the request. Make sure Sign in with Apple is enabled in Xcode and Apple Developer.',
      ),
      AuthorizationErrorCode.invalidResponse => t(
        'وصل رد غير صالح من Apple. جرّب مرة ثانية.',
        'Apple returned an invalid response. Try again.',
      ),
      AuthorizationErrorCode.notHandled => t(
        'Apple لم تستطع معالجة الطلب. غالباً صلاحية Sign in with Apple غير مفعّلة للتطبيق.',
        'Apple could not handle the request. Sign in with Apple is probably not enabled for this app.',
      ),
      AuthorizationErrorCode.notInteractive => t(
        'Apple يحتاج فتح نافذة الدخول. جرّب من جديد والجهاز مفتوح.',
        'Apple needs to show the sign-in prompt. Try again with the device unlocked.',
      ),
      AuthorizationErrorCode.unknown => t(
        'فشل الدخول عبر Apple. تحقق من إعدادات Apple و Firebase.',
        'Apple sign-in failed. Check Apple and Firebase settings.',
      ),
      AuthorizationErrorCode.canceled => '',
    };
  }

  String _firebaseAppleMessage(FirebaseAuthException e) {
    final details = e.message == null || e.message!.trim().isEmpty
        ? e.code
        : '${e.code}: ${e.message}';

    return switch (e.code) {
      'operation-not-allowed' => t(
        'لازم تفعيل Apple من Firebase Authentication.\n$details',
        'Enable Apple in Firebase Authentication.\n$details',
      ),
      'account-exists-with-different-credential' => t(
        'هذا الإيميل مسجل بطريقة دخول ثانية. جرّب Google أو الإيميل.\n$details',
        'This email already uses another sign-in method. Try Google or email.\n$details',
      ),
      'invalid-credential' ||
      'invalid-oauth-provider' ||
      'missing-apple-token' => t(
        'إعداد Apple غير مكتمل. تأكد من Bundle ID و Firebase.\n$details',
        'Apple setup is incomplete. Check the Bundle ID and Firebase.\n$details',
      ),
      _ => '${t('فشل الدخول عبر Apple', 'Apple sign-in failed')}\n$details',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: yahalaPageBg(widget.isDark),
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          centerTitle: true,
          title: Text(
            t('تسجيل الدخول', 'Login'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              yahalaLogo(width: 130),

              const SizedBox(height: 30),

              _input(
                controller: emailController,
                hint: t('الإيميل', 'Email'),
                icon: Icons.email,
              ),

              const SizedBox(height: 14),

              _input(
                controller: passwordController,
                hint: t('كلمة السر', 'Password'),
                icon: Icons.lock,
                obscure: true,
              ),

              Align(
                alignment: widget.isArabic
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading ? null : resetPassword,
                  child: Text(
                    t('نسيت كلمة المرور؟', 'Forgot password?'),
                    style: const TextStyle(
                      color: yaHalaGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yaHalaGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: isLoading ? null : login,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          t('دخول', 'Login'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: isLoading ? null : signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 32),
                  label: Text(
                    t('الدخول عبر Google', 'Continue with Google'),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: isLoading ? null : signInWithApple,
                  icon: Icon(
                    Icons.apple,
                    color: widget.isDark ? Colors.white : Colors.black,
                    size: 28,
                  ),
                  label: Text(
                    t('الدخول عبر Apple', 'Continue with Apple'),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black,
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

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

String _generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();

  return List.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

String _sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}
