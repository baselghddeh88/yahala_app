import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ad_actions.dart';
import '../utils/value_formatters.dart';
import '../widgets/favorite_button.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class DetailsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;
  final String title;
  final String subtitle;
  final String city;
  final String price;
  final String views;
  final String imageUrl;
  final List<String> imageUrls;
  final String description;
  final String phone;
  final String adId;
  final Map<String, dynamic> data;

  const DetailsScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.price,
    required this.views,
    this.imageUrl = '',
    this.imageUrls = const [],
    this.description = '',
    this.phone = '',
    this.adId = '',
    this.data = const {},
  });

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  bool get isArabic => widget.isArabic;
  bool get isDark => widget.isDark;
  String get adId => widget.adId;
  Map<String, dynamic> get data => widget.data;

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _recordViewOnce();
  }

  Future<void> _recordViewOnce() async {
    if (adId.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && data['userId']?.toString() == user.uid) return;

    final prefs = await SharedPreferences.getInstance();
    final viewKey = 'viewed_ad_$adId';
    if (prefs.getBool(viewKey) == true) return;

    try {
      await FirebaseFirestore.instance.collection('ads').doc(adId).update({
        'views': FieldValue.increment(1),
      });
      await prefs.setBool(viewKey, true);
    } catch (_) {
      // View counts should not block reading the ad.
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.imageUrls.isNotEmpty
        ? widget.imageUrls
        : [widget.imageUrl];
    final hasContactOptions =
        data.containsKey('allowCall') ||
        data.containsKey('allowSms') ||
        data.containsKey('allowInAppMessage');
    final allowCall = hasContactOptions ? data['allowCall'] == true : true;
    final allowSms = hasContactOptions ? data['allowSms'] == true : true;
    final allowInAppMessage = data['allowInAppMessage'] == true;
    final showCall = allowCall && widget.phone.trim().isNotEmpty;
    final showSms = allowSms && widget.phone.trim().isNotEmpty;
    final address = data['address']?.toString() ?? '';
    final zipCode = data['zipCode']?.toString() ?? '';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? bgDark : Colors.white,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          elevation: 0,
          centerTitle: true,
          title: Text(
            t('تفاصيل الإعلان', 'Ad Details'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _photoGallery(images, isArabic, isDark),
                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark ? cardColor : const Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 18),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? bgDark : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.price.isEmpty
                                    ? t('غير محدد', 'Not specified')
                                    : formatMoney(widget.price),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: yaHalaGold,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.city.isEmpty ? '-' : widget.city,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (address.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.map_outlined,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (zipCode.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.pin_drop,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      zipCode,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),

                              _viewsCountRow(),
                              const SizedBox(height: 10),
                              _favoritesCountRow(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),
                        Divider(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                        const SizedBox(height: 18),

                        Text(
                          t('الوصف', 'Description'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Text(
                          widget.description.isEmpty
                              ? t('لا يوجد وصف', 'No description')
                              : widget.description,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 28),

                        Row(
                          children: [
                            if (showCall)
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: yaHalaGreen,
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => AdActions.callPhone(
                                    context,
                                    widget.phone,
                                    isArabic: isArabic,
                                  ),
                                  icon: const Icon(
                                    Icons.phone,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    t('اتصال', 'Call'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            if (showCall && (showSms || allowInAppMessage))
                              const SizedBox(width: 10),

                            if (showSms)
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: yaHalaGold,
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => AdActions.sendSms(
                                    context,
                                    widget.phone,
                                    isArabic: isArabic,
                                  ),
                                  icon: const Icon(
                                    Icons.sms,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    t('رسالة', 'SMS'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            if (showSms && allowInAppMessage)
                              const SizedBox(width: 10),
                            if (allowInAppMessage)
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey,
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => AdActions.openInAppChat(
                                    context,
                                    adId: adId,
                                    data: data,
                                    isArabic: isArabic,
                                    isDark: isDark,
                                  ),
                                  icon: const Icon(
                                    Icons.chat,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    t('التطبيق', 'App'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),

                            Container(
                              height: 52,
                              width: 52,
                              decoration: BoxDecoration(
                                color: isDark ? bgDark : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              child: FavoriteButton(
                                adId: adId,
                                data: data,
                                isArabic: isArabic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _favoritesCountRow() {
    if (adId.isEmpty) {
      return _favoritesRow(data['favoritesCount']);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .doc(adId)
          .snapshots(),
      builder: (context, snapshot) {
        final liveData = snapshot.data?.data();
        return _favoritesRow(
          liveData?['favoritesCount'] ?? data['favoritesCount'],
        );
      },
    );
  }

  Widget _viewsCountRow() {
    if (adId.isEmpty) {
      return _viewsRow(data['views']);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .doc(adId)
          .snapshots(),
      builder: (context, snapshot) {
        final liveData = snapshot.data?.data();
        return _viewsRow(liveData?['views'] ?? data['views']);
      },
    );
  }

  Widget _viewsRow(dynamic views) {
    return Row(
      children: [
        const Icon(Icons.visibility, color: Colors.grey, size: 18),
        const SizedBox(width: 6),
        Text(
          _formattedViews(views),
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _favoritesRow(dynamic favoritesCount) {
    return Row(
      children: [
        const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
        const SizedBox(width: 6),
        Text(
          isArabic
              ? '${_intValue(favoritesCount)} بالمفضلة'
              : '${_intValue(favoritesCount)} favorites',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  String _formattedViews(dynamic liveViews) {
    final count = _intValue(liveViews ?? widget.views);
    return isArabic ? '$count مشاهدة' : '$count views';
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final digits = '$value'.replaceAll(RegExp(r'[^0-9-]'), '');
    return int.tryParse(digits) ?? 0;
  }
}

Widget _photoGallery(List<String> images, bool isArabic, bool isDark) {
  final validImages = images.where((url) => url.isNotEmpty).toList();

  if (validImages.isEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 310,
        width: double.infinity,
        color: isDark ? cardColor : const Color(0xFFF3F3F3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 44,
              color: Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              isArabic ? 'لا توجد صورة' : 'No image',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: SizedBox(
      height: 310,
      width: double.infinity,
      child: PageView.builder(
        itemCount: validImages.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _FullImageViewer(imageUrl: validImages[index]),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  validImages[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: isDark ? cardColor : const Color(0xFFF3F3F3),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        size: 44,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${index + 1} / ${validImages.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.open_in_full,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _FullImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.7,
          maxScale: 5,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 60,
            ),
          ),
        ),
      ),
    );
  }
}
