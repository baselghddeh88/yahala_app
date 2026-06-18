import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import 'admin_screen.dart';

class AdminGateScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;

  const AdminGateScreen({super.key, this.isArabic = true, this.isDark = false});

  @override
  State<AdminGateScreen> createState() => _AdminGateScreenState();
}

class _AdminGateScreenState extends State<AdminGateScreen> {
  static const adminEmails = {'samghddeh@gmail.com'};

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

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack(t('عبّي الإيميل وكلمة السر', 'Enter email and password'));
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (_) {
      if (mounted) {
        _snack(t('فشل تسجيل الدخول', 'Login failed'));
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<bool> _isAdmin(User user) async {
    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser ?? user;
    final email = refreshedUser.email?.trim().toLowerCase() ?? '';
    if (adminEmails.contains(email)) return true;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(refreshedUser.uid)
        .get();
    final data = doc.data();
    return data?['isAdmin'] == true ||
        data?['IsAdmin'] == true ||
        data?['role'] == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          final user = authSnapshot.data;

          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return _loadingScaffold();
          }

          if (user == null) {
            return _loginScaffold();
          }

          return FutureBuilder<bool>(
            future: _isAdmin(user),
            builder: (context, adminSnapshot) {
              if (!adminSnapshot.hasData) {
                return _loadingScaffold();
              }

              if (adminSnapshot.data != true) {
                return _notAllowedScaffold(user.email ?? '');
              }

              return AdminScreen(
                isArabic: widget.isArabic,
                isDark: widget.isDark,
              );
            },
          );
        },
      ),
    );
  }

  Widget _loadingScaffold() {
    return Scaffold(
      backgroundColor: yahalaPageBg(widget.isDark),
      body: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(yahalaGreen),
        ),
      ),
    );
  }

  Widget _loginScaffold() {
    return Scaffold(
      backgroundColor: yahalaPageBg(widget.isDark),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: yahalaCardBg(widget.isDark),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  yahalaLogo(width: 96),
                  const SizedBox(height: 18),
                  Text(
                    t('لوحة إدارة يا هلا', 'Yahala Admin'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: yahalaText(widget.isDark),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'سجّل دخول بحساب الأدمن لإدارة الإعلانات والأسئلة.',
                      'Sign in with an admin account to manage ads and questions.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: yahalaMutedText(widget.isDark)),
                  ),
                  const SizedBox(height: 22),
                  _input(
                    controller: emailController,
                    hint: t('الإيميل', 'Email'),
                    icon: Icons.email,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    controller: passwordController,
                    hint: t('كلمة السر', 'Password'),
                    icon: Icons.lock,
                    obscure: true,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: yahalaGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isLoading ? null : _login,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.admin_panel_settings),
                      label: Text(
                        isLoading
                            ? t('جاري الدخول...', 'Signing in...')
                            : t('دخول', 'Login'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notAllowedScaffold(String email) {
    return Scaffold(
      backgroundColor: yahalaPageBg(widget.isDark),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: yahalaGold, size: 60),
                const SizedBox(height: 16),
                Text(
                  t('هذا الحساب ليس أدمن', 'This account is not an admin'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: yahalaText(widget.isDark),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: yahalaMutedText(widget.isDark)),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yahalaGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: Text(t('تسجيل الخروج', 'Sign out')),
                ),
              ],
            ),
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
      keyboardType: obscure ? TextInputType.text : TextInputType.emailAddress,
      textInputAction: obscure ? TextInputAction.done : TextInputAction.next,
      onSubmitted: (_) {
        if (obscure && !isLoading) _login();
      },
      style: TextStyle(color: yahalaText(widget.isDark)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: yahalaMutedText(widget.isDark)),
        prefixIcon: Icon(icon, color: yahalaGreen),
        filled: true,
        fillColor: widget.isDark
            ? const Color(0xFF101B28)
            : const Color(0xFFF3F3F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
