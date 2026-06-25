import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'details_screen.dart';
import 'add_post_screen.dart';
import 'search_screen.dart';
import '../services/ad_actions.dart';
import '../utils/ad_promotion.dart';
import '../utils/value_formatters.dart';
import '../widgets/contact_actions_wrap.dart';
import '../widgets/favorite_button.dart';
import '../widgets/paid_category_ads.dart';
import '../widgets/section_filter_panel.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class HousingScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;

  const HousingScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
  });

  @override
  State<HousingScreen> createState() => _HousingScreenState();
}

class _HousingScreenState extends State<HousingScreen> {
  final queryController = TextEditingController();
  final cityController = TextEditingController();
  final zipController = TextEditingController();

  bool get isArabic => widget.isArabic;
  bool get isDark => widget.isDark;

  String query = '';
  String cityFilter = '';
  String zipFilter = '';
  bool get hasActiveFilters =>
      query.isNotEmpty || cityFilter.isNotEmpty || zipFilter.isNotEmpty;

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  void dispose() {
    queryController.dispose();
    cityController.dispose();
    zipController.dispose();
    super.dispose();
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    final city = data['city']?.toString().toLowerCase() ?? '';
    final address = data['address']?.toString().toLowerCase() ?? '';
    final zip = data['zipCode']?.toString().toLowerCase() ?? '';
    final text = [
      data['title'],
      data['description'],
      data['price'],
      data['housingType'],
      city,
      address,
      zip,
    ].whereType<Object>().join(' ').toLowerCase();

    return (query.isEmpty || text.contains(query)) &&
        (cityFilter.isEmpty || city.contains(cityFilter)) &&
        (zipFilter.isEmpty || zip.startsWith(zipFilter));
  }

  void _clearFilters() {
    setState(() {
      query = '';
      cityFilter = '';
      zipFilter = '';
      queryController.clear();
      cityController.clear();
      zipController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? bgDark : Colors.white,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          elevation: 0,
          centerTitle: true,
          title: Text(
            t('سكن', 'Housing'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _searchBox(context, t('ابحث عن سكن...', 'Search housing...')),

              const SizedBox(height: 16),
              _filterPanel(t('فلتر السكن', 'Housing filter')),

              const SizedBox(height: 16),

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
                          isArabic: isArabic,
                          isDark: isDark,
                          initialCategory: 'سكن',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    t('أضف عقار', 'Add Property'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),
              PaidCategoryAds(
                isArabic: isArabic,
                isDark: isDark,
                category: 'سكن',
                icon: Icons.home,
              ),

              const SizedBox(height: 22),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ads')
                    .where('category', isEqualTo: 'سكن')
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

                  final ads = sortAdsByPromotion(
                    (snapshot.data?.docs ?? []).where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _matchesFilters(data);
                    }),
                  );

                  if (ads.isEmpty) {
                    return Text(
                      t('لا توجد عقارات بعد', 'No properties yet'),
                      style: const TextStyle(color: Colors.grey),
                    );
                  }

                  return Column(
                    children: ads.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      final title =
                          data['title']?.toString() ??
                          t('عقار بدون عنوان', 'Untitled Property');
                      final description = data['description']?.toString() ?? '';
                      final city = data['city']?.toString() ?? '';
                      final price = data['price']?.toString() ?? '';
                      final views = data['views']?.toString() ?? '0';
                      final imageUrl = data['imageUrl']?.toString() ?? '';
                      final imageUrls = List<String>.from(
                        data['imageUrls'] ?? [],
                      );
                      final phone = data['phone']?.toString() ?? '';
                      final housingType = data['housingType']?.toString() ?? '';

                      return _housingCard(
                        context: context,
                        adId: doc.id,
                        data: data,
                        isArabic: isArabic,
                        isDark: isDark,
                        title: title,
                        description: description,
                        city: city,
                        price: price.isEmpty
                            ? t('غير محدد', 'Not set')
                            : formatMoney(price),
                        views: isArabic ? '$views مشاهدة' : '$views views',
                        imageUrl: imageUrl,
                        imageUrls: imageUrls,
                        phone: phone,
                        housingType: housingType,
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBox(BuildContext context, String hint) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchScreen(isArabic: isArabic, isDark: isDark),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? cardColor : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterPanel(String title) {
    return SectionFilterPanel(
      isArabic: isArabic,
      isDark: isDark,
      title: title,
      searchHint: t('ابحث عن سكن', 'Search housing'),
      searchController: queryController,
      cityController: cityController,
      zipController: zipController,
      hasActiveFilters: hasActiveFilters,
      onClear: _clearFilters,
      onSearchChanged: (value) {
        setState(() => query = value.trim().toLowerCase());
      },
      onCitySelected: (value) {
        setState(() => cityFilter = value.trim().toLowerCase());
      },
      onZipChanged: (value) {
        setState(() => zipFilter = value.trim().toLowerCase());
      },
    );
  }
}

Widget _housingCard({
  required BuildContext context,
  required String adId,
  required Map<String, dynamic> data,
  required bool isArabic,
  required bool isDark,
  required String title,
  required String description,
  required String city,
  required String price,
  required String views,
  required String imageUrl,
  required List<String> imageUrls,
  required String phone,
  required String housingType,
}) {
  final subtitle = description.isEmpty
      ? (isArabic ? 'تفاصيل العقار' : 'Property details')
      : description;
  final hasContactOptions =
      data.containsKey('allowCall') ||
      data.containsKey('allowSms') ||
      data.containsKey('allowInAppMessage');
  final allowCall = hasContactOptions ? data['allowCall'] == true : true;
  final allowSms = hasContactOptions ? data['allowSms'] == true : true;
  final allowInAppMessage = data['allowInAppMessage'] == true;
  final showCall = allowCall && phone.trim().isNotEmpty;
  final showSms = allowSms && phone.trim().isNotEmpty;

  return InkWell(
    borderRadius: BorderRadius.circular(22),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailsScreen(
            isArabic: isArabic,
            isDark: isDark,
            title: title,
            subtitle: subtitle,
            city: city,
            price: price,
            views: views,
            imageUrl: imageUrl,
            imageUrls: imageUrls,
            description: description,
            phone: phone,
            adId: adId,
            data: data,
          ),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
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
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                imageUrl,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? bgDark : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.image, color: Colors.grey, size: 42),
            ),

          const SizedBox(height: 14),

          if (housingType.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: yaHalaGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                housingType,
                style: const TextStyle(
                  color: yaHalaGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: Colors.grey),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  city.isEmpty ? '-' : city,
                  style: const TextStyle(color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: yaHalaGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.visibility, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              Text(views, style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              if (imageUrls.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? bgDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isArabic
                        ? '${imageUrls.length} صور'
                        : '${imageUrls.length} photos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          ContactActionsWrap(
            actions: [
              if (showCall)
                ContactActionData(
                  color: yaHalaGreen,
                  icon: Icons.phone,
                  label: isArabic ? 'اتصال' : 'Call',
                  onPressed: () =>
                      AdActions.callPhone(context, phone, isArabic: isArabic),
                ),
              if (showSms)
                ContactActionData(
                  color: yaHalaGold,
                  icon: Icons.sms,
                  label: isArabic ? 'رسالة نصية' : 'Text',
                  onPressed: () =>
                      AdActions.sendSms(context, phone, isArabic: isArabic),
                ),
              if (allowInAppMessage)
                ContactActionData(
                  color: Colors.blueGrey,
                  icon: Icons.chat,
                  label: isArabic ? 'رسالة عبر يا هلا' : 'Message via Ya Hala',
                  onPressed: () => AdActions.openInAppChat(
                    context,
                    adId: adId,
                    data: data,
                    isArabic: isArabic,
                    isDark: isDark,
                  ),
                ),
            ],
            trailing: FavoriteButton(
              adId: adId,
              data: data,
              isArabic: isArabic,
            ),
          ),
        ],
      ),
    ),
  );
}
