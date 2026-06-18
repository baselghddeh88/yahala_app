import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class CouponScannerScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;

  const CouponScannerScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
  });

  @override
  State<CouponScannerScreen> createState() => _CouponScannerScreenState();
}

class _CouponScannerScreenState extends State<CouponScannerScreen> {
  final codeController = TextEditingController();
  bool loading = false;
  QueryDocumentSnapshot? claimDoc;
  Map<String, dynamic>? couponData;
  String? message;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: widget.isDark ? bgDark : Colors.white,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          centerTitle: true,
          title: Text(
            t('تحقق من كوبون', 'Verify Coupon'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.qr_code_scanner, color: yaHalaGold, size: 34),
                  const SizedBox(height: 12),
                  Text(
                    t(
                      'أدخل كود الكوبون الذي يظهر عند الزبون.',
                      'Enter the coupon code shown by the customer.',
                    ),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: yaHalaGold, width: 1.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: loading ? null : _openCameraScanner,
                      icon: const Icon(Icons.photo_camera, color: yaHalaGold),
                      label: Text(
                        t('مسح بالكاميرا', 'Scan with camera'),
                        style: const TextStyle(
                          color: yaHalaGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                    decoration: InputDecoration(
                      hintText: 'YH-ABC123',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: widget.isDark ? bgDark : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: yaHalaGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: loading ? null : _verifyCode,
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.search, color: Colors.white),
                      label: Text(
                        t('تحقق', 'Verify'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (message != null) _messageBox(message!),
            if (claimDoc != null && couponData != null)
              _resultCard(claimDoc!, couponData!),
          ],
        ),
      ),
    );
  }

  Future<void> _openCameraScanner() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CouponCameraScannerScreen(
          isArabic: widget.isArabic,
          isDark: widget.isDark,
        ),
      ),
    );

    if (scannedCode == null || scannedCode.trim().isEmpty) return;

    codeController.text = _extractCouponCode(scannedCode);
    await _verifyCode();
  }

  String _extractCouponCode(String value) {
    final text = value.trim().toUpperCase();
    final match = RegExp(r'YH-[A-Z0-9]+').firstMatch(text);
    return match?.group(0) ?? text;
  }

  Widget _messageBox(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _resultCard(QueryDocumentSnapshot claim, Map<String, dynamic> coupon) {
    final claimData = claim.data() as Map<String, dynamic>;
    final status = claimData['status']?.toString() ?? 'active';
    final code = claimData['code']?.toString() ?? '';
    final title = coupon['title']?.toString() ?? t('كوبون', 'Coupon');
    final userEmail = claimData['userEmail']?.toString() ?? '';
    final used = status == 'used';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: used ? Colors.grey : yaHalaGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                used ? Icons.check_circle : Icons.verified,
                color: used ? Colors.grey : yaHalaGreen,
              ),
              const SizedBox(width: 8),
              Text(
                used
                    ? t('مستخدم سابقاً', 'Already used')
                    : t('كوبون صالح', 'Valid coupon'),
                style: TextStyle(
                  color: used ? Colors.grey : yaHalaGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(code, style: const TextStyle(color: yaHalaGold, fontSize: 18)),
          if (userEmail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(userEmail, style: const TextStyle(color: Colors.grey)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: used ? Colors.grey : yaHalaGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: used || loading ? null : () => _useCoupon(claim.id),
              icon: const Icon(Icons.done_all, color: Colors.white),
              label: Text(
                used
                    ? t('تم استخدامه', 'Used')
                    : t('استخدام الكوبون', 'Redeem coupon'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyCode() async {
    final user = FirebaseAuth.instance.currentUser;
    final code = codeController.text.trim().toUpperCase();
    if (user == null || code.isEmpty) return;

    setState(() {
      loading = true;
      claimDoc = null;
      couponData = null;
      message = null;
    });

    try {
      final claims = await FirebaseFirestore.instance
          .collection('couponClaims')
          .where('code', isEqualTo: code)
          .where('merchantId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (claims.docs.isEmpty) {
        setState(
          () => message = t(
            'الكود غير موجود أو ليس تابعاً لعروضك',
            'Code not found or not yours',
          ),
        );
        return;
      }

      final claim = claims.docs.first;
      final data = claim.data();
      final couponId = data['couponId']?.toString() ?? '';
      final coupon = await FirebaseFirestore.instance
          .collection('ads')
          .doc(couponId)
          .get();

      setState(() {
        claimDoc = claim;
        couponData = coupon.data() ?? {};
      });
    } catch (_) {
      setState(
        () => message = t('تعذر التحقق من الكود', 'Could not verify code'),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _useCoupon(String claimId) async {
    setState(() => loading = true);

    try {
      final claimRef = FirebaseFirestore.instance
          .collection('couponClaims')
          .doc(claimId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final claim = await transaction.get(claimRef);
        final claimData = claim.data() ?? {};
        if (claimData['status'] == 'used') return;

        final couponId = claimData['couponId']?.toString() ?? '';
        transaction.update(claimRef, {
          'status': 'used',
          'usedAt': FieldValue.serverTimestamp(),
          'usedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        });
        if (couponId.isNotEmpty) {
          transaction.update(
            FirebaseFirestore.instance.collection('ads').doc(couponId),
            {'usedCount': FieldValue.increment(1)},
          );
        }
      });

      await _verifyCode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('تم استخدام الكوبون', 'Coupon redeemed'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تعذر استخدام الكوبون', 'Could not redeem coupon')),
        ),
      );
    }

    if (mounted) setState(() => loading = false);
  }
}

class CouponCameraScannerScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;

  const CouponCameraScannerScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
  });

  @override
  State<CouponCameraScannerScreen> createState() =>
      _CouponCameraScannerScreenState();
}

class _CouponCameraScannerScreenState extends State<CouponCameraScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool scanned = false;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          centerTitle: true,
          title: Text(
            t('مسح الكوبون', 'Scan Coupon'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => controller.toggleTorch(),
              icon: const Icon(Icons.flashlight_on, color: Colors.white),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (scanned) return;
                String? value;
                for (final barcode in capture.barcodes) {
                  final rawValue = barcode.rawValue;
                  if (rawValue != null && rawValue.trim().isNotEmpty) {
                    value = rawValue;
                    break;
                  }
                }
                if (value == null || value.trim().isEmpty) return;

                scanned = true;
                Navigator.pop(context, value);
              },
            ),
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: yaHalaGold, width: 4),
                ),
              ),
            ),
            PositionedDirectional(
              start: 22,
              end: 22,
              bottom: 36,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  t(
                    'وجّه الكاميرا على كود الكوبون',
                    'Point the camera at the coupon code',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
