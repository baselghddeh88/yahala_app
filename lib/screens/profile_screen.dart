import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_choice_screen.dart';
import 'my_ads_screen.dart';
import 'favorites_screen.dart';
import 'edit_profile_screen.dart';
import 'admin_screen.dart';
import 'coupon_scanner_screen.dart';
import 'legal_screen.dart';
import 'contact_us_screen.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class ProfileScreen extends StatelessWidget {
  final bool isArabic;
  final bool isDark;
  final bool showAppBar;

  const ProfileScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    this.showAppBar = true,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return AuthChoiceScreen(isArabic: isArabic, isDark: isDark);
    }

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? bgDark : Colors.white,
        appBar: showAppBar
            ? AppBar(
                backgroundColor: yaHalaGreen,
                centerTitle: true,
                title: Text(
                  t('حسابي', 'My Account'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;

                  final name = data?['name']?.toString() ?? '';
                  final photoUrl = data?['photoUrl']?.toString() ?? '';

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? cardColor : const Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: yaHalaGreen,
                          backgroundImage: photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 40,
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name.isEmpty ? (user.email ?? '') : name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
              if ((user.email ?? '').isNotEmpty && !user.emailVerified)
                _tile(
                  context,
                  icon: Icons.mark_email_unread,
                  title: t('تأكيد الإيميل', 'Verify Email'),
                  onTap: () async {
                    try {
                      await user.sendEmailVerification();

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            t(
                              'أرسلنا رابط التأكيد إلى بريدك',
                              'Verification link sent to your email',
                            ),
                          ),
                        ),
                      );
                    } on FirebaseAuthException catch (_) {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            t(
                              'تعذر إرسال رابط التأكيد الآن',
                              'Could not send verification link now',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              _tile(
                context,
                icon: Icons.edit,
                title: t('تعديل الحساب', 'Edit Profile'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EditProfileScreen(isArabic: isArabic, isDark: isDark),
                    ),
                  );
                },
              ),
              _tile(
                context,
                icon: Icons.list_alt,
                title: t('إعلاناتي', 'My Ads'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MyAdsScreen(isArabic: isArabic, isDark: isDark),
                    ),
                  );
                },
              ),

              _tile(
                context,
                icon: Icons.favorite,
                title: t('المفضلة', 'Favorites'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FavoritesScreen(isArabic: isArabic, isDark: isDark),
                    ),
                  );
                },
              ),
              _tile(
                context,
                icon: Icons.qr_code_scanner,
                title: t('تحقق من كوبون', 'Verify Coupon'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CouponScannerScreen(
                        isArabic: isArabic,
                        isDark: isDark,
                      ),
                    ),
                  );
                },
              ),
              _tile(
                context,
                icon: Icons.privacy_tip,
                title: t('الشروط والخصوصية', 'Terms & Privacy'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LegalScreen(isArabic: isArabic, isDark: isDark),
                    ),
                  );
                },
              ),
              _tile(
                context,
                icon: Icons.support_agent,
                title: t('تواصل معنا', 'Contact Us'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ContactUsScreen(isArabic: isArabic, isDark: isDark),
                    ),
                  );
                },
              ),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final isAdmin =
                      data?['isAdmin'] == true || data?['role'] == 'admin';

                  if (!isAdmin) return const SizedBox.shrink();

                  return _tile(
                    context,
                    icon: Icons.admin_panel_settings,
                    title: t('لوحة الإدارة', 'Admin Dashboard'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminScreen(isArabic: isArabic, isDark: isDark),
                        ),
                      );
                    },
                  );
                },
              ),

              _tile(
                context,
                icon: Icons.logout,
                title: t('تسجيل الخروج', 'Logout'),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();

                  if (!context.mounted) return;

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) =>
                          AuthChoiceScreen(isArabic: isArabic, isDark: isDark),
                    ),
                    (route) => false,
                  );
                },
              ),
              _tile(
                context,
                icon: Icons.delete_forever,
                title: t('حذف الحساب', 'Delete Account'),
                danger: true,
                onTap: () => _confirmDeleteAccount(context, user),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        tileColor: isDark ? cardColor : const Color(0xFFF3F3F3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: danger ? Colors.redAccent : yaHalaGreen),
        title: Text(
          title,
          style: TextStyle(
            color: danger
                ? Colors.redAccent
                : (isDark ? Colors.white : Colors.black),
          ),
        ),
        trailing: Icon(
          isArabic ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios,
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context, User user) async {
    final reasonController = TextEditingController();
    String? reasonError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: isDark ? cardColor : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(t('حذف الحساب', 'Delete Account')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(
                    'اكتب سبب الحذف حتى نراجع الطلب ونحسن التجربة. السبب مطلوب.',
                    'Tell us why you want to delete the account. The reason is required.',
                  ),
                  style: const TextStyle(color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: t('سبب الحذف', 'Deletion reason'),
                    errorText: reasonError,
                    filled: true,
                    fillColor: isDark ? bgDark : const Color(0xFFF3F5F1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(t('إلغاء', 'Cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: yaHalaGold,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (reasonController.text.trim().isEmpty) {
                    setDialogState(() {
                      reasonError = t(
                        'سبب الحذف مطلوب',
                        'Deletion reason is required',
                      );
                    });
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: Text(t('تأكيد الحذف', 'Confirm Delete')),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() ?? {};
    final name =
        userData['name']?.toString() ?? user.displayName ?? user.email ?? '';

    await FirebaseFirestore.instance
        .collection('deletionRequests')
        .doc(user.uid)
        .set({
          'userId': user.uid,
          'email': user.email ?? '',
          'name': name,
          'reason': reason,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'deletionRequested': true,
      'deletionReason': reason,
      'deletionRequestedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t('تم إرسال طلب حذف الحساب', 'Account deletion request sent'),
        ),
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AuthChoiceScreen(isArabic: isArabic, isDark: isDark),
      ),
      (route) => false,
    );
  }
}
