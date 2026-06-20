import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';

class ContactUsScreen extends StatelessWidget {
  final bool isArabic;
  final bool isDark;

  const ContactUsScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: yahalaPageBg(isDark),
        appBar: AppBar(
          backgroundColor: yahalaGreen,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(
            t('تواصل معنا', 'Contact Us'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: yahalaCardBg(isDark),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('نحن هنا لمساعدتك', 'We are here to help'),
                    style: TextStyle(
                      color: yahalaText(isDark),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'للدعم، الملاحظات، مشاكل الحساب، أو طلبات الإعلانات.',
                      'For support, feedback, account issues, or ad requests.',
                    ),
                    style: TextStyle(
                      color: yahalaMutedText(isDark),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _contactTile(
                    icon: Icons.email,
                    label: t('البريد الإلكتروني', 'Email'),
                    value: 'support@yahalaus.com',
                    onTap: () => _open(
                      Uri(
                        scheme: 'mailto',
                        path: 'support@yahalaus.com',
                        queryParameters: {'subject': 'Yahala Support'},
                      ),
                    ),
                  ),
                  _contactTile(
                    icon: Icons.phone,
                    label: t('رقم الهاتف', 'Phone'),
                    value: '209 488 0000',
                    onTap: () => _open(Uri(scheme: 'tel', path: '2094880000')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? yahalaDarkBg : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: yahalaGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: yahalaMutedText(isDark),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: yahalaText(isDark),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: yahalaGold, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
