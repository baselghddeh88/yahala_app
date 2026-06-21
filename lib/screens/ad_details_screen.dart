import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ad_actions.dart';
import '../utils/category_subtypes.dart';
import '../utils/value_formatters.dart';
import '../widgets/favorite_button.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class AdDetailsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;
  final Map<String, dynamic> data;
  final String adId;

  const AdDetailsScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    required this.data,
    this.adId = '',
  });

  @override
  State<AdDetailsScreen> createState() => _AdDetailsScreenState();
}

class _AdDetailsScreenState extends State<AdDetailsScreen> {
  bool get isArabic => widget.isArabic;
  bool get isDark => widget.isDark;
  Map<String, dynamic> get data => widget.data;
  String get adId => widget.adId;

  @override
  void initState() {
    super.initState();
    _recordViewOnce();
  }

  String t(String ar, String en) => isArabic ? ar : en;

  Future<void> _recordViewOnce() async {
    if (adId.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || data['userId']?.toString() == user.uid) return;

    final prefs = await SharedPreferences.getInstance();
    final viewKey = 'viewed_ad_$adId';
    if (prefs.getBool(viewKey) == true) return;

    try {
      await FirebaseFirestore.instance.collection('ads').doc(adId).update({
        'views': FieldValue.increment(1),
      });
      await prefs.setBool(viewKey, true);
    } catch (_) {
      // View counts are nice-to-have; never block the details page for them.
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? '';
    final description = data['description']?.toString() ?? '';
    final city = data['city']?.toString() ?? '';
    final address = data['address']?.toString() ?? '';
    final zipCode = data['zipCode']?.toString() ?? '';
    final phone = data['phone']?.toString() ?? '';
    final formattedPhone = formatPhoneNumber(phone);
    final category = data['category']?.toString() ?? '';
    final rawPrice = isRestaurantOrStoreCategory(category)
        ? ''
        : data['price']?.toString() ?? '';
    final price = rawPrice.isEmpty ? '' : formatMoney(rawPrice);
    final eventDate = _formatTimestampDate(data['eventDate']);
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final imageUrls = List<String>.from(data['imageUrls'] ?? []);
    final hasContactOptions =
        data.containsKey('allowCall') ||
        data.containsKey('allowSms') ||
        data.containsKey('allowInAppMessage');
    final allowCall = hasContactOptions ? data['allowCall'] == true : true;
    final allowSms = hasContactOptions ? data['allowSms'] == true : true;
    final allowInAppMessage = data['allowInAppMessage'] == true;
    final showCall = allowCall && phone.trim().isNotEmpty;
    final showSms = allowSms && phone.trim().isNotEmpty;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? bgDark : Colors.white,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          centerTitle: true,
          title: Text(
            t('تفاصيل الإعلان', 'Ad Details'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            FavoriteButton(
              adId: adId,
              data: data,
              isArabic: isArabic,
              savedColor: Colors.redAccent,
              unsavedColor: Colors.white,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _imageGallery(imageUrl, imageUrls),

              const SizedBox(height: 18),

              Text(
                title.isEmpty ? t('إعلان بدون عنوان', 'Untitled Ad') : title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(category.isEmpty ? t('عام', 'General') : category),
                  if (city.isNotEmpty) _chip(city),
                  if (zipCode.isNotEmpty) _chip(zipCode),
                  if (eventDate.isNotEmpty) _chip(eventDate, gold: true),
                  if (price.isNotEmpty) _chip(price, gold: true),
                ],
              ),

              const SizedBox(height: 22),

              if (city.isNotEmpty ||
                  address.isNotEmpty ||
                  zipCode.isNotEmpty ||
                  eventDate.isNotEmpty ||
                  phone.isNotEmpty)
                _infoBox(
                  children: [
                    if (eventDate.isNotEmpty)
                      _infoRow(
                        Icons.event,
                        t('تاريخ الفعالية', 'Event date'),
                        eventDate,
                      ),
                    if (city.isNotEmpty)
                      _infoRow(Icons.location_city, t('المدينة', 'City'), city),
                    if (address.isNotEmpty)
                      _infoRow(
                        Icons.location_on,
                        t('العنوان', 'Address'),
                        address,
                        onTap: () => AdActions.openMap(
                          context,
                          address,
                          city: city,
                          zipCode: zipCode,
                          isArabic: isArabic,
                        ),
                      ),
                    if (zipCode.isNotEmpty)
                      _infoRow(Icons.pin_drop, 'ZIP', zipCode),
                    if (phone.isNotEmpty)
                      _infoRow(
                        Icons.phone,
                        t('الهاتف', 'Phone'),
                        formattedPhone,
                        valueDirection: TextDirection.ltr,
                        onTap: () => AdActions.callPhone(
                          context,
                          phone,
                          isArabic: isArabic,
                        ),
                      ),
                  ],
                ),

              if (city.isNotEmpty ||
                  address.isNotEmpty ||
                  zipCode.isNotEmpty ||
                  phone.isNotEmpty)
                const SizedBox(height: 22),

              _sectionTitle(t('الوصف', 'Description')),
              const SizedBox(height: 8),

              Text(
                description.isEmpty
                    ? t('لا يوجد وصف', 'No description')
                    : description,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              if (showCall || showSms || allowInAppMessage)
                Row(
                  children: [
                    if (showCall)
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: yaHalaGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => AdActions.callPhone(
                              context,
                              phone,
                              isArabic: isArabic,
                            ),
                            icon: const Icon(Icons.phone, color: Colors.white),
                            label: Text(
                              t('اتصال', 'Call'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (showCall && (showSms || allowInAppMessage))
                      const SizedBox(width: 10),
                    if (showSms)
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: yaHalaGold,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => AdActions.sendSms(
                              context,
                              phone,
                              isArabic: isArabic,
                            ),
                            icon: const Icon(Icons.sms, color: Colors.white),
                            label: Text(
                              t('رسالة', 'SMS'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (showSms && allowInAppMessage) const SizedBox(width: 10),
                    if (allowInAppMessage)
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => AdActions.openInAppChat(
                              context,
                              adId: adId,
                              data: data,
                              isArabic: isArabic,
                              isDark: isDark,
                            ),
                            icon: const Icon(Icons.chat, color: Colors.white),
                            label: Text(
                              t('التطبيق', 'App'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, {bool gold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: gold
            ? yaHalaGold.withValues(alpha: 0.18)
            : yaHalaGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: gold ? yaHalaGold : yaHalaGreen,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _infoBox({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
    TextDirection? valueDirection,
  }) {
    final displayValue = isolateLeftToRight(value);
    final effectiveDirection =
        valueDirection ??
        (containsLatinOrDigits(value)
            ? TextDirection.ltr
            : isArabic
            ? TextDirection.rtl
            : TextDirection.ltr);

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: yaHalaGreen, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
          Expanded(
            child: Directionality(
              textDirection: effectiveDirection,
              child: Text(
                displayValue,
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                style: TextStyle(
                  color: onTap == null ? Colors.grey : yaHalaGreen,
                  fontWeight: onTap == null ? FontWeight.w500 : FontWeight.w900,
                  decoration: onTap == null ? null : TextDecoration.underline,
                  decorationColor: yaHalaGreen,
                ),
              ),
            ),
          ),
          if (onTap != null)
            const Icon(Icons.open_in_new, color: yaHalaGold, size: 16),
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }

  Widget _imageGallery(String imageUrl, List<String> imageUrls) {
    final images = imageUrls.isNotEmpty
        ? imageUrls
        : (imageUrl.isNotEmpty ? [imageUrl] : <String>[]);

    if (images.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 220,
          width: double.infinity,
          color: isDark ? cardColor : const Color(0xFFF3F3F3),
          child: const Icon(Icons.image, color: Colors.grey, size: 60),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsetsDirectional.only(
              end: index == images.length - 1 ? 0 : 8,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _FullImageViewer(imageUrl: images[index]),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(images[index], fit: BoxFit.cover),
                    PositionedDirectional(
                      bottom: 10,
                      end: 10,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.open_in_full,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    if (images.length > 1)
                      PositionedDirectional(
                        top: 10,
                        end: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${index + 1}/${images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestampDate(dynamic value) {
    if (value is! Timestamp) return '';
    final date = value.toDate();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
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
