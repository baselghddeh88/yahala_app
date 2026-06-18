import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'add_post_screen.dart';
import 'auth_choice_screen.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class CouponsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;

  const CouponsScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
  });

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  bool claiming = false;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: widget.isDark ? bgDark : Colors.white,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          elevation: 0,
          centerTitle: true,
          title: Text(
            t('الكوبونات', 'Coupons'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: yaHalaGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPostScreen(
                        isArabic: widget.isArabic,
                        isDark: widget.isDark,
                        initialCategory: 'كوبون',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(
                  t('أضف كوبون', 'Add Coupon'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ads')
                  .where('category', isEqualTo: 'كوبون')
                  .where('status', isEqualTo: 'approved')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.red),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(yaHalaGreen),
                      ),
                    ),
                  );
                }

                final coupons = snapshot.data?.docs ?? [];

                if (coupons.isEmpty) {
                  return Text(
                    t('لا توجد كوبونات بعد', 'No coupons yet'),
                    style: const TextStyle(color: Colors.grey),
                  );
                }

                return Column(
                  children: coupons.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _couponCard(doc.id, data);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _couponCard(String couponId, Map<String, dynamic> data) {
    final user = FirebaseAuth.instance.currentUser;
    final title =
        data['title']?.toString() ?? t('كوبون بدون عنوان', 'Untitled Coupon');
    final merchantName =
        data['merchantName']?.toString() ??
        data['description']?.toString() ??
        '';
    final address =
        data['address']?.toString() ?? data['city']?.toString() ?? '';
    final terms = data['couponTerms']?.toString() ?? '';
    final discount = _offerLabel(data);
    final endDate = _dateFrom(data['couponEndsAt']);
    final limit = _intFrom(data['couponLimit']);
    final claimed = _intFrom(data['claimedCount']);
    final used = _intFrom(data['usedCount']);
    final expired = endDate != null && endDate.isBefore(DateTime.now());
    final soldOut = limit > 0 && claimed >= limit;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: yaHalaGold,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  discount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.local_offer, color: yaHalaGold),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: widget.isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (merchantName.isNotEmpty)
            Text(
              merchantName,
              textAlign: widget.isArabic ? TextAlign.right : TextAlign.left,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              if (address.isNotEmpty) _meta(Icons.location_on, address),
              if (endDate != null)
                _meta(
                  Icons.event,
                  t(
                    'ينتهي ${_formatDate(endDate)}',
                    'Ends ${_formatDate(endDate)}',
                  ),
                ),
              _meta(
                Icons.confirmation_number,
                limit > 0
                    ? t('$claimed من $limit', '$claimed of $limit')
                    : t('$claimed كوبون', '$claimed coupons'),
              ),
              _meta(Icons.check_circle, t('مستخدم $used', 'Used $used')),
            ],
          ),
          if (terms.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${t('الشروط', 'Terms')}: $terms',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
          const SizedBox(height: 18),
          if (user == null)
            _couponButton(
              label: t('سجّل دخول لتحصل على الكوبون', 'Sign in to get coupon'),
              icon: Icons.login,
              color: yaHalaGreen,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuthChoiceScreen(
                      isArabic: widget.isArabic,
                      isDark: widget.isDark,
                    ),
                  ),
                );
              },
            )
          else
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('couponClaims')
                  .doc('${couponId}_${user.uid}')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _couponButton(
                    label: t(
                      'يحتاج تحديث صلاحيات الكوبونات',
                      'Coupon permissions need updating',
                    ),
                    icon: Icons.lock_outline,
                    color: Colors.grey,
                    onTap: null,
                  );
                }

                final claim = snapshot.data?.data() as Map<String, dynamic>?;
                final code = claim?['code']?.toString() ?? '';
                final status = claim?['status']?.toString() ?? 'active';

                if (code.isNotEmpty) {
                  return _claimedBox(code, status, data);
                }

                final disabled = claiming || expired || soldOut;
                return _couponButton(
                  label: expired
                      ? t('انتهى العرض', 'Expired')
                      : soldOut
                      ? t('انتهت الكمية', 'Sold out')
                      : t('الحصول على الكوبون', 'Get Coupon'),
                  icon: Icons.card_giftcard,
                  color: disabled ? Colors.grey : yaHalaGreen,
                  onTap: disabled ? null : () => _claimCoupon(couponId, data),
                );
              },
            ),
        ],
      ),
    );

    return card;
  }

  Widget _couponButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        icon: claiming
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _claimedBox(String code, String status, Map<String, dynamic> data) {
    final used = status == 'used';
    return _couponButton(
      label: used
          ? t('عرض الكوبون المستخدم', 'View used coupon')
          : t('عرض الكوبون للسكرين شوت', 'Open coupon for screenshot'),
      icon: used ? Icons.check_circle : Icons.qr_code_2,
      color: used ? Colors.grey : yaHalaGreen,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CouponCodeScreen(
              isArabic: widget.isArabic,
              isDark: widget.isDark,
              couponData: data,
              code: code,
              status: status,
            ),
          ),
        );
      },
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.grey, size: 16),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Future<void> _claimCoupon(String couponId, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => claiming = true);

    try {
      final couponRef = FirebaseFirestore.instance
          .collection('ads')
          .doc(couponId);
      final claimRef = FirebaseFirestore.instance
          .collection('couponClaims')
          .doc('${couponId}_${user.uid}');

      final generatedCode = _generateCode();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final couponSnap = await transaction.get(couponRef);
        final claimSnap = await transaction.get(claimRef);

        if (claimSnap.exists) return;
        final coupon = couponSnap.data() ?? {};
        final limit = _intFrom(coupon['couponLimit']);
        final claimed = _intFrom(coupon['claimedCount']);
        final endDate = _dateFrom(coupon['couponEndsAt']);

        if (endDate != null && endDate.isBefore(DateTime.now())) {
          throw Exception('expired');
        }
        if (limit > 0 && claimed >= limit) {
          throw Exception('sold-out');
        }

        transaction.set(claimRef, {
          'couponId': couponId,
          'userId': user.uid,
          'userEmail': user.email ?? '',
          'merchantId': coupon['userId']?.toString() ?? '',
          'code': generatedCode,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(couponRef, {
          'claimedCount': FieldValue.increment(1),
        });
      });

      if (!mounted) return;
      _snack(t('تم إصدار الكوبون', 'Coupon issued'));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CouponCodeScreen(
            isArabic: widget.isArabic,
            isDark: widget.isDark,
            couponData: data,
            code: generatedCode,
            status: 'active',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _snack(
        error.toString().contains('permission-denied')
            ? t(
                'صلاحيات الكوبونات تحتاج تحديث',
                'Coupon permissions need updating',
              )
            : t('تعذر إصدار الكوبون', 'Could not issue coupon'),
      );
    }

    if (mounted) setState(() => claiming = false);
  }

  String _offerLabel(Map<String, dynamic> data) {
    final type = data['couponType']?.toString() ?? 'special';
    final value =
        data['couponValue']?.toString() ?? data['price']?.toString() ?? '';
    if (value.isEmpty) return t('عرض', 'Offer');
    if (type == 'percent') return '$value%';
    if (type == 'amount') return '-$value';
    return value;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final suffix = List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'YH-$suffix';
  }

  int _intFrom(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class CouponCodeScreen extends StatelessWidget {
  final bool isArabic;
  final bool isDark;
  final Map<String, dynamic> couponData;
  final String code;
  final String status;

  const CouponCodeScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    required this.couponData,
    required this.code,
    required this.status,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final title =
        couponData['title']?.toString() ?? t('كوبون يا هلا', 'Yahala Coupon');
    final merchantName =
        couponData['merchantName']?.toString() ??
        couponData['description']?.toString() ??
        '';
    final address =
        couponData['address']?.toString() ??
        couponData['city']?.toString() ??
        '';
    final offer = _offerLabel(couponData);
    final endDate = _dateFrom(couponData['couponEndsAt']);
    final used = status == 'used';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? bgDark : const Color(0xFFF7F8F6),
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          elevation: 0,
          centerTitle: true,
          title: Text(
            t('كوبوني', 'My Coupon'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE5E5E5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: yaHalaGold,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          offer,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: yaHalaGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.local_offer,
                          color: yaHalaGreen,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  if (merchantName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      merchantName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      address,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  Container(
                    width: 190,
                    height: 190,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F7F0),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: yaHalaGreen, width: 2),
                    ),
                    child: QrImageView(
                      data: code,
                      version: QrVersions.auto,
                      gapless: false,
                      backgroundColor: const Color(0xFFF3F7F0),
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: yaHalaGreen,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: yaHalaGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t('كود المسح والاستخدام', 'Scan/use code'),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: yaHalaGold,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: used
                          ? Colors.grey.withValues(alpha: 0.12)
                          : yaHalaGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      used
                          ? t('تم استخدام هذا الكوبون', 'This coupon was used')
                          : endDate == null
                          ? t(
                              'اعرض هذه الصفحة عند المحل',
                              'Show this page at the store',
                            )
                          : t(
                              'صالح حتى ${_formatDate(endDate)}',
                              'Valid until ${_formatDate(endDate)}',
                            ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: used ? Colors.grey : yaHalaGreen,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t(
                      'يا هلا - جالية العرب في كاليفورنيا',
                      'Yahala - Arab community in California',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 12,
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

  String _offerLabel(Map<String, dynamic> data) {
    final type = data['couponType']?.toString() ?? 'special';
    final value =
        data['couponValue']?.toString() ?? data['price']?.toString() ?? '';
    if (value.isEmpty) return t('عرض', 'Offer');
    if (type == 'percent') return '$value%';
    if (type == 'amount') return '-$value';
    return value;
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
