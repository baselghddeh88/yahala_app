import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import 'home_screen.dart';
import '../services/app_settings.dart';
import '../services/notification_service.dart';
import 'legal_screen.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class RegisterScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;

  const RegisterScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool acceptedLegal = false;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('عبّي جميع الحقول', 'Please fill all fields')),
        ),
      );
      return;
    }

    if (!acceptedLegal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'لازم توافق على الشروط وسياسة الخصوصية',
              'Please accept the Terms and Privacy Policy',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      await userCredential.user?.updateDisplayName(nameController.text.trim());
      await userCredential.user?.sendEmailVerification();
      await AppSettings.save(isArabic: widget.isArabic, isDark: widget.isDark);
      await AppSettings.saveLegalAccepted();
      await NotificationService.saveFcmToken();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'name': nameController.text.trim(),
            'email': emailController.text.trim(),
            'emailVerified': false,
            'phone': '',
            'authProvider': 'email',
            'acceptedTerms': true,
            'acceptedPrivacy': true,
            'legalVersion': AppSettings.legalVersion,
            'acceptedLegalAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          });

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
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = t('هذا الإيميل مستخدم مسبقاً', 'Email already in use');
          break;
        case 'invalid-email':
          message = t('الإيميل غير صالح', 'Invalid email address');
          break;
        case 'weak-password':
          message = t('كلمة السر ضعيفة', 'Weak password');
          break;
        case 'keychain-error':
          message = t(
            'مشكلة في صلاحيات الجهاز، أعد تشغيل التطبيق',
            'Device keychain permission issue',
          );
          break;
        default:
          message = e.message ?? t('حدث خطأ', 'Something went wrong');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(message)),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            e.message ?? t('حدث خطأ في قاعدة البيانات', 'Database error'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(t('حدث خطأ غير متوقع', 'Unexpected error occurred')),
        ),
      );
    }

    if (mounted) setState(() => isLoading = false);
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
            t('إنشاء حساب', 'Create Account'),
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
              const SizedBox(height: 30),
              yahalaLogo(width: 130),
              const SizedBox(height: 30),
              _input(
                controller: nameController,
                hint: t('الاسم', 'Name'),
                icon: Icons.person,
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 24),
              _legalConsentBox(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yaHalaGold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: isLoading ? null : register,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          t('إنشاء حساب', 'Create Account'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
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

  Widget _legalConsentBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: CheckboxListTile(
        value: acceptedLegal,
        activeColor: yaHalaGreen,
        contentPadding: EdgeInsets.zero,
        controlAffinity: widget.isArabic
            ? ListTileControlAffinity.leading
            : ListTileControlAffinity.trailing,
        onChanged: (value) {
          setState(() => acceptedLegal = value ?? false);
        },
        title: Text(
          t(
            'أوافق على شروط الاستخدام وسياسة الخصوصية',
            'I agree to the Terms of Use and Privacy Policy',
          ),
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: TextButton(
          onPressed: _openLegalScreen,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: widget.isArabic
                ? Alignment.centerRight
                : Alignment.centerLeft,
          ),
          child: Text(t('قراءة الشروط والخصوصية', 'Read terms and privacy')),
        ),
      ),
    );
  }

  void _openLegalScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LegalScreen(isArabic: widget.isArabic, isDark: widget.isDark),
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
