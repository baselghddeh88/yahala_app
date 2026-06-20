import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ad_details_screen.dart';
import 'add_post_screen.dart';
import '../utils/ad_promotion.dart';
import '../utils/value_formatters.dart';
import '../widgets/city_picker_field.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class CategoryAdsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;
  final String category;
  final String titleAr;
  final String titleEn;
  final IconData icon;

  const CategoryAdsScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    required this.category,
    required this.titleAr,
    required this.titleEn,
    required this.icon,
  });

  @override
  State<CategoryAdsScreen> createState() => _CategoryAdsScreenState();
}

class _CategoryAdsScreenState extends State<CategoryAdsScreen> {
  final queryController = TextEditingController();
  final cityController = TextEditingController();
  final zipController = TextEditingController();

  bool get isArabic => widget.isArabic;
  bool get isDark => widget.isDark;
  String get category => widget.category;
  String get titleAr => widget.titleAr;
  String get titleEn => widget.titleEn;
  IconData get icon => widget.icon;

  String query = '';
  String cityFilter = '';
  String zipFilter = '';

  String t(String ar, String en) => isArabic ? ar : en;
  bool get isRestaurantOrStore => category == 'مطاعم ومحلات';

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
      data['phone'],
      city,
      address,
      zip,
    ].whereType<Object>().join(' ').toLowerCase();

    return (query.isEmpty || text.contains(query)) &&
        (cityFilter.isEmpty || city.contains(cityFilter)) &&
        (zipFilter.isEmpty || zip.startsWith(zipFilter));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? bgDark : Colors.white,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          centerTitle: true,
          title: Text(
            t(titleAr, titleEn),
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
              _addButton(context),
              const SizedBox(height: 22),
              _categoryFeaturedAds(context),
              const SizedBox(height: 22),
              _filterPanel(),
              const SizedBox(height: 22),
              _sectionTitle(
                isRestaurantOrStore
                    ? t('آخر المطاعم والمحلات', 'Latest restaurants and stores')
                    : t('آخر الإعلانات', 'Latest ads'),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ads')
                    .where('category', isEqualTo: category)
                    .where('status', isEqualTo: 'approved')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      snapshot.error.toString(),
                      style: const TextStyle(color: Colors.red),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(yaHalaGreen),
                        ),
                      ),
                    );
                  }

                  final ads = sortAdsByPromotion(
                    snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _matchesFilters(data);
                    }),
                  );

                  if (ads.isEmpty) {
                    return Text(
                      t('لا توجد إعلانات بعد', 'No ads yet'),
                      style: const TextStyle(color: Colors.grey),
                    );
                  }

                  return Column(
                    children: ads.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _adCard(context, doc.id, data);
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

  Widget _filterPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? cardColor : const Color(0xFFF3F3F3),
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
            t('فلتر $titleAr', '$titleEn filter'),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _filterInput(
            controller: queryController,
            hint: t('ابحث داخل القسم', 'Search this section'),
            icon: Icons.search,
            onChanged: (value) {
              setState(() => query = value.trim().toLowerCase());
            },
          ),
          Row(
            children: [
              Expanded(
                child: CityPickerField(
                  controller: cityController,
                  isArabic: isArabic,
                  isDark: isDark,
                  hint: t('المدينة', 'City'),
                  onSelected: (value) =>
                      setState(() => cityFilter = value.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _filterInput(
                  controller: zipController,
                  hint: 'ZIP',
                  icon: Icons.pin_drop,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() => zipFilter = value.trim().toLowerCase());
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: yaHalaGreen),
          filled: true,
          fillColor: isDark ? bgDark : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    return SizedBox(
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
                initialCategory: category,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          isRestaurantOrStore
              ? t('أضف مطعم أو محل', 'Add restaurant or store')
              : t('أضف إعلان', 'Add ad'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _categoryFeaturedAds(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .where('category', isEqualTo: category)
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final featured = sortPaidAdsByPromotion(
          snapshot.data!.docs,
        ).take(15).toList();

        if (featured.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(t('مميز في هذا القسم', 'Featured in this section')),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: featured.length,
                itemBuilder: (context, index) {
                  final doc = featured[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return SizedBox(
                    width: 260,
                    child: _featuredCard(context, doc.id, data),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _featuredCard(
    BuildContext context,
    String adId,
    Map<String, dynamic> data,
  ) {
    final title = data['title']?.toString() ?? '';
    final city = data['city']?.toString() ?? data['address']?.toString() ?? '';
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final vip = isVipAd(data);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdDetailsScreen(
              isArabic: isArabic,
              isDark: isDark,
              data: data,
              adId: adId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? cardColor : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: yaHalaGold.withValues(alpha: 0.35)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl.isEmpty
                ? Icon(icon, color: Colors.grey, size: 44)
                : Image.network(imageUrl, fit: BoxFit.cover),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 10,
              start: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: vip ? yaHalaGreen : yaHalaGold,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  vip ? t('VIP', 'VIP') : t('مميز', 'Featured'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: 14,
              end: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? t('إعلان مميز', 'Featured ad') : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    );
  }

  Widget _adCard(BuildContext context, String adId, Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? '';
    final description = data['description']?.toString() ?? '';
    final city = data['city']?.toString() ?? '';
    final rawPrice = isRestaurantOrStore ? '' : data['price']?.toString() ?? '';
    final price = rawPrice.isEmpty ? '' : formatMoney(rawPrice);
    final eventDate = _formatTimestampDate(data['eventDate']);
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final trailingInfo = eventDate.isNotEmpty ? eventDate : price;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdDetailsScreen(
              isArabic: isArabic,
              isDark: isDark,
              data: data,
              adId: adId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? cardColor : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl.isEmpty
                  ? Container(
                      width: 76,
                      height: 76,
                      color: isDark ? bgDark : Colors.white,
                      child: Icon(icon, color: Colors.grey),
                    )
                  : Image.network(
                      imageUrl,
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty
                        ? t('إعلان بدون عنوان', 'Untitled ad')
                        : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (city.isNotEmpty)
                        Expanded(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (city.isNotEmpty && trailingInfo.isNotEmpty)
                        const SizedBox(width: 8),
                      if (trailingInfo.isNotEmpty)
                        Flexible(
                          child: Text(
                            trailingInfo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: yaHalaGold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
