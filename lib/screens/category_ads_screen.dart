import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ad_details_screen.dart';
import 'add_post_screen.dart';
import '../utils/ad_promotion.dart';
import '../utils/category_subtype_suggestions.dart';
import '../utils/category_subtypes.dart';
import '../utils/value_formatters.dart';
import '../widgets/promoted_ad_frame.dart';
import '../widgets/section_filter_panel.dart';

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
  final String? initialSubCategory;
  final String? initialSubCategoryTitleAr;
  final String? initialSubCategoryTitleEn;

  const CategoryAdsScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    required this.category,
    required this.titleAr,
    required this.titleEn,
    required this.icon,
    this.initialSubCategory,
    this.initialSubCategoryTitleAr,
    this.initialSubCategoryTitleEn,
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
  String get pageTitleAr => widget.initialSubCategoryTitleAr ?? titleAr;
  String get pageTitleEn => widget.initialSubCategoryTitleEn ?? titleEn;
  IconData get icon => widget.icon;

  String query = '';
  String cityFilter = '';
  String zipFilter = '';
  String subCategoryFilter = '';

  String t(String ar, String en) => isArabic ? ar : en;
  bool get isRestaurantOrStore => isRestaurantOrStoreCategory(category);
  bool get isSubCategoryPage => widget.initialSubCategory != null;
  bool get hasSubtypeFilters =>
      category != restaurantCategory &&
      subtypesForCategory(category).isNotEmpty;
  bool get hasDynamicSubtypes =>
      category == storesCategory || category == 'محامين وهجرة';
  bool get keepsSubtypesWithPriority => category == 'محامين وهجرة';
  bool get hasActiveFilters =>
      query.isNotEmpty ||
      cityFilter.isNotEmpty ||
      zipFilter.isNotEmpty ||
      (hasSubtypeFilters && subCategoryFilter.isNotEmpty);
  List<String> get categoryQueryValues => category == restaurantCategory
      ? [restaurantCategory, legacyRestaurantStoreCategory]
      : [category];

  Stream<QuerySnapshot> _adsStream() {
    var query = FirebaseFirestore.instance
        .collection('ads')
        .where('status', isEqualTo: 'approved');

    if (categoryQueryValues.length == 1) {
      query = query.where('category', isEqualTo: category);
    } else {
      query = query.where('category', whereIn: categoryQueryValues);
    }

    return query.snapshots();
  }

  @override
  void initState() {
    super.initState();
    subCategoryFilter = widget.initialSubCategory ?? '';
  }

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
      data['subCategory'],
      data['subCategoryLabelAr'],
      data['subCategoryLabelEn'],
      city,
      address,
      zip,
    ].whereType<Object>().join(' ').toLowerCase();

    return (query.isEmpty || text.contains(query)) &&
        (subCategoryFilter.isEmpty ||
            data['subCategory']?.toString() == subCategoryFilter) &&
        (cityFilter.isEmpty || city.contains(cityFilter)) &&
        (zipFilter.isEmpty || zip.startsWith(zipFilter));
  }

  void _clearFilters() {
    setState(() {
      query = '';
      cityFilter = '';
      zipFilter = '';
      if (!isSubCategoryPage) subCategoryFilter = '';
      queryController.clear();
      cityController.clear();
      zipController.clear();
    });
  }

  bool get _showsPrioritySection =>
      !(hasSubtypeFilters &&
          subCategoryFilter.isEmpty &&
          !keepsSubtypesWithPriority);

  List<QueryDocumentSnapshot<Object?>> _visiblePriorityAds(
    Iterable<QueryDocumentSnapshot<Object?>> docs,
  ) {
    if (!_showsPrioritySection) return const [];

    return sortPaidAdsByPromotion(
      docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return isCategoryTopAd(data);
      }),
    ).take(categoryTopAdSlots).toList();
  }

  Set<String> _visiblePriorityAdIds(
    Iterable<QueryDocumentSnapshot<Object?>> docs,
  ) {
    return _visiblePriorityAds(docs).map((doc) => doc.id).toSet();
  }

  List<QueryDocumentSnapshot<Object?>> _sortVisibleAds(
    Iterable<QueryDocumentSnapshot<Object?>> docs,
  ) {
    final visible = docs.toList();
    if (hasSubtypeFilters &&
        subCategoryFilter.isEmpty &&
        !keepsSubtypesWithPriority) {
      visible.sort(compareAdsNewestFirst);
      return visible;
    }
    return sortAdsByPromotion(visible);
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
            t(pageTitleAr, pageTitleEn),
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
              _filterPanel(),
              const SizedBox(height: 22),
              _addButton(context),
              const SizedBox(height: 22),
              if (hasSubtypeFilters && !isSubCategoryPage) ...[
                _subtypeDirectory(),
                const SizedBox(height: 22),
              ],
              _categoryFeaturedAds(context),
              const SizedBox(height: 22),
              StreamBuilder<QuerySnapshot>(
                stream: _adsStream(),
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

                  final matchedAds = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _matchesFilters(data);
                  }).toList();
                  final priorityIds = _visiblePriorityAdIds(matchedAds);
                  final ads = _sortVisibleAds(
                    matchedAds.where((doc) => !priorityIds.contains(doc.id)),
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
    return SectionFilterPanel(
      isArabic: isArabic,
      isDark: isDark,
      title: t('فلتر $pageTitleAr', '$pageTitleEn filter'),
      searchHint: t('ابحث داخل القسم', 'Search this section'),
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
      extraFilter: hasSubtypeFilters && !isSubCategoryPage
          ? _subCategoryDropdown()
          : null,
    );
  }

  IconData _subtypeIcon(String value) {
    return switch (value) {
      'market' => Icons.storefront,
      'phone_store' => Icons.phone_iphone,
      'clothing' => Icons.checkroom,
      'jewelry' => Icons.diamond,
      'furniture' => Icons.chair,
      'beauty_store' => Icons.spa,
      'auto_parts' => Icons.car_repair,
      'immigration' => Icons.flight_takeoff,
      'accident' => Icons.health_and_safety,
      'family' => Icons.family_restroom,
      'business' => Icons.business_center,
      'consultation' => Icons.record_voice_over,
      'notary' => Icons.edit_document,
      _ => icon,
    };
  }

  Widget _subtypeDirectory() {
    if (!hasSubtypeFilters) return const SizedBox.shrink();

    if (hasDynamicSubtypes) {
      return StreamBuilder<List<CategorySubtypeOption>>(
        stream: approvedCategorySubtypesStream(category, isArabic),
        builder: (context, snapshot) {
          return _subtypeDirectoryGrid([
            ...subtypesForCategory(category),
            ...(snapshot.data ?? const <CategorySubtypeOption>[]),
          ]);
        },
      );
    }

    return _subtypeDirectoryGrid(subtypesForCategory(category));
  }

  Widget _subtypeDirectoryGrid(List<CategorySubtypeOption> options) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(t('الأقسام الفرعية', 'Subcategories')),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: options.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.92,
          ),
          itemBuilder: (context, index) {
            final option = options[index];
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryAdsScreen(
                      isArabic: isArabic,
                      isDark: isDark,
                      category: category,
                      titleAr: titleAr,
                      titleEn: titleEn,
                      icon: _subtypeIcon(option.value),
                      initialSubCategory: option.value,
                      initialSubCategoryTitleAr: option.ar,
                      initialSubCategoryTitleEn: option.en,
                    ),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? cardColor : const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _subtypeIcon(option.value),
                      color: yaHalaGreen,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isArabic ? option.ar : option.en,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _subtypeCountBadge(option.value),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _subtypeCountBadge(String subtype) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('ads')
        .where('status', isEqualTo: 'approved')
        .where('subCategory', isEqualTo: subtype);

    if (categoryQueryValues.length == 1) {
      query = query.where('category', isEqualTo: category);
    } else {
      query = query.where('category', whereIn: categoryQueryValues);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Text(
          isArabic ? '$count إعلان' : '$count ads',
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey.shade600,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }

  Widget _subCategoryDropdown() {
    if (hasDynamicSubtypes) {
      return StreamBuilder<List<CategorySubtypeOption>>(
        stream: approvedCategorySubtypesStream(category, isArabic),
        builder: (context, snapshot) {
          return _subCategoryDropdownControl([
            ...subtypesForCategory(category),
            ...(snapshot.data ?? const <CategorySubtypeOption>[]),
          ]);
        },
      );
    }

    return _subCategoryDropdownControl(subtypesForCategory(category));
  }

  Widget _subCategoryDropdownControl(List<CategorySubtypeOption> options) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? bgDark : Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: subCategoryFilter.isEmpty ? null : subCategoryFilter,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: yaHalaGreen),
          dropdownColor: isDark ? cardColor : Colors.white,
          hint: Text(
            t('كل الأنواع', 'All types'),
            style: const TextStyle(color: Colors.grey),
          ),
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text(
                t('كل الأنواع', 'All types'),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
            ),
            ...options.map(
              (option) => DropdownMenuItem<String>(
                value: option.value,
                child: Text(
                  isArabic ? option.ar : option.en,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => subCategoryFilter = value ?? '');
          },
        ),
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
                initialSubCategory: subCategoryFilter.isEmpty
                    ? null
                    : subCategoryFilter,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          isRestaurantOrStore
              ? category == storesCategory
                    ? t('أضف محل تجاري', 'Add store')
                    : t('أضف مطعم أو كافيه', 'Add restaurant or cafe')
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
    if (!_showsPrioritySection) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _adsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final featured = _visiblePriorityAds(
          snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _matchesFilters(data);
          }),
        );

        if (featured.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(t('أولوية الظهور', 'Priority listings')),
            const SizedBox(height: 10),
            Column(
              children: featured.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _adCard(context, doc.id, data, promoted: true);
              }).toList(),
            ),
          ],
        );
      },
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

  Widget _adCard(
    BuildContext context,
    String adId,
    Map<String, dynamic> data, {
    bool promoted = false,
  }) {
    final title = data['title']?.toString() ?? '';
    final description = data['description']?.toString() ?? '';
    final city = data['city']?.toString() ?? '';
    final rawPrice = isRestaurantOrStore ? '' : data['price']?.toString() ?? '';
    final price = rawPrice.isEmpty ? '' : formatMoney(rawPrice);
    final eventDate = _formatTimestampDate(data['eventDate']);
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final trailingInfo = eventDate.isNotEmpty ? eventDate : price;

    final card = InkWell(
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
        margin: promoted ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
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
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
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

    if (!promoted) return card;

    return PromotedAdFrame(
      isDark: isDark,
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(20),
      child: card,
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
