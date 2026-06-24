import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'details_screen.dart';
import 'add_post_screen.dart';
import 'search_screen.dart';
import '../services/ad_actions.dart';
import '../utils/ad_promotion.dart';
import '../utils/category_subtypes.dart';
import '../utils/value_formatters.dart';
import '../widgets/contact_actions_wrap.dart';
import '../widgets/favorite_button.dart';
import '../widgets/paid_category_ads.dart';
import '../widgets/section_filter_panel.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class ServicesScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;
  final String? initialSubCategory;
  final String? initialTitleAr;
  final String? initialTitleEn;

  const ServicesScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    this.initialSubCategory,
    this.initialTitleAr,
    this.initialTitleEn,
  });

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final queryController = TextEditingController();
  final cityController = TextEditingController();
  final zipController = TextEditingController();

  bool get isArabic => widget.isArabic;
  bool get isDark => widget.isDark;

  String query = '';
  String cityFilter = '';
  String zipFilter = '';
  String subCategoryFilter = '';

  String t(String ar, String en) => isArabic ? ar : en;
  bool get isSubCategoryPage => widget.initialSubCategory != null;
  bool get hasSubtypeFilters => serviceSubtypes.isNotEmpty;
  bool get hasActiveFilters =>
      query.isNotEmpty ||
      cityFilter.isNotEmpty ||
      zipFilter.isNotEmpty ||
      (!isSubCategoryPage && subCategoryFilter.isNotEmpty);
  Set<String> get serviceSubtypeValues =>
      serviceSubtypes.map((option) => option.value).toSet();
  String get pageTitle => t(
    widget.initialTitleAr ?? 'الخدمات',
    widget.initialTitleEn ?? 'Services',
  );

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
      data['subCategory'],
      data['subCategoryLabelAr'],
      data['subCategoryLabelEn'],
      city,
      address,
      zip,
    ].whereType<Object>().join(' ').toLowerCase();

    return (query.isEmpty || text.contains(query)) &&
        _matchesSelectedSubtype(data) &&
        (cityFilter.isEmpty || city.contains(cityFilter)) &&
        (zipFilter.isEmpty || zip.startsWith(zipFilter));
  }

  bool _matchesSelectedSubtype(Map<String, dynamic> data) {
    if (subCategoryFilter.isEmpty) return true;

    final subCategory = data['subCategory']?.toString().trim() ?? '';
    if (subCategoryFilter == 'catering_service') {
      return subCategory == subCategoryFilter || _isCateringService(data);
    }
    if (subCategoryFilter == 'government_services') {
      return subCategory == subCategoryFilter || _isGovernmentService(data);
    }
    if (subCategoryFilter == 'insurance') {
      return subCategory == subCategoryFilter || _isInsuranceService(data);
    }
    if (subCategoryFilter != 'other') return subCategory == subCategoryFilter;

    if (_isKnownServiceAlias(data)) return false;

    final labelAr = data['subCategoryLabelAr']?.toString().trim() ?? '';
    final labelEn = data['subCategoryLabelEn']?.toString().trim() ?? '';
    return subCategory.isEmpty ||
        subCategory == 'other' ||
        labelAr == 'خدمة أخرى' ||
        labelEn.toLowerCase() == 'other service' ||
        !serviceSubtypeValues.contains(subCategory);
  }

  bool _isKnownServiceAlias(Map<String, dynamic> data) {
    return _isCateringService(data) ||
        _isGovernmentService(data) ||
        _isInsuranceService(data);
  }

  bool _isCateringService(Map<String, dynamic> data) {
    return _serviceTextMatches(data, const [
      'catering_service',
      'catering',
      'food catering',
      'كاترينج',
      'كاترنج',
      'كيترينج',
      'ضيافة',
      'تموين',
      'طبخ مناسبات',
    ]);
  }

  bool _isGovernmentService(Map<String, dynamic> data) {
    return _serviceTextMatches(data, const [
      'government_services',
      'government service',
      'government services',
      'dmv',
      'passport',
      'uscis',
      'معاملات حكومية',
      'معاملة حكومية',
      'دوائر حكومية',
      'خدمات حكومية',
      'جوازات',
      'جواز سفر',
      'اقامة',
      'إقامة',
      'هجرة',
    ]);
  }

  bool _isInsuranceService(Map<String, dynamic> data) {
    return _serviceTextMatches(data, const [
      'insurance',
      'انشرانس',
      'انشورنس',
      'تأمين',
      'تامين',
      'تأمين سيارات',
      'تامين سيارات',
      'تأمين صحي',
      'تامين صحي',
      'تأمين منزل',
      'تامين منزل',
      'auto insurance',
      'health insurance',
      'home insurance',
      'life insurance',
    ]);
  }

  bool _serviceTextMatches(Map<String, dynamic> data, List<String> needles) {
    final text = [
      data['title'],
      data['description'],
      data['subCategory'],
      data['subCategoryLabelAr'],
      data['subCategoryLabelEn'],
    ].whereType<Object>().join(' ').toLowerCase();

    return needles.any((needle) => text.contains(needle.toLowerCase()));
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

  List<QueryDocumentSnapshot<Object?>> _sortVisibleServices(
    Iterable<QueryDocumentSnapshot<Object?>> docs,
  ) {
    final visible = docs.toList();
    if (hasSubtypeFilters && subCategoryFilter.isEmpty) {
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
            pageTitle,
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
              _searchBox(context, t('ابحث عن خدمة...', 'Search services...')),
              const SizedBox(height: 16),
              _filterPanel(t('فلتر الخدمات', 'Services filter')),

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
                          initialCategory: 'خدمة',
                          initialSubCategory: subCategoryFilter.isEmpty
                              ? null
                              : subCategoryFilter,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    t('أضف خدمة', 'Add Service'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),
              if (!isSubCategoryPage) ...[
                _serviceDirectory(),
                const SizedBox(height: 22),
              ],
              PaidCategoryAds(
                isArabic: isArabic,
                isDark: isDark,
                category: 'خدمة',
                subCategory: subCategoryFilter,
                icon: Icons.handyman,
              ),

              const SizedBox(height: 22),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ads')
                    .where('category', isEqualTo: 'خدمة')
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

                  final services = _sortVisibleServices(
                    (snapshot.data?.docs ?? []).where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _matchesFilters(data);
                    }),
                  );

                  if (services.isEmpty) {
                    return Text(
                      t('لا توجد خدمات بعد', 'No services yet'),
                      style: const TextStyle(color: Colors.grey),
                    );
                  }

                  return Column(
                    children: services.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      final title =
                          data['title']?.toString() ??
                          t('خدمة بدون عنوان', 'Untitled Service');
                      final description = data['description']?.toString() ?? '';
                      final city = data['city']?.toString() ?? '';
                      final price = data['price']?.toString() ?? '';
                      final views = data['views']?.toString() ?? '0';
                      final imageUrl = data['imageUrl']?.toString() ?? '';
                      final imageUrls = List<String>.from(
                        data['imageUrls'] ?? [],
                      );
                      final phone = data['phone']?.toString() ?? '';

                      return _serviceCard(
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

  IconData _serviceIcon(String value) {
    return switch (value) {
      'plumbing' => Icons.plumbing,
      'electrician' => Icons.electrical_services,
      'carpenter' => Icons.handyman,
      'cleaning' => Icons.cleaning_services,
      'painting' => Icons.format_paint,
      'moving' => Icons.local_shipping,
      'ac_repair' => Icons.ac_unit,
      'camera_security' => Icons.videocam,
      'taxes' => Icons.receipt_long,
      'notary' => Icons.edit_document,
      'translation' => Icons.translate,
      'beauty' => Icons.spa,
      'education' => Icons.school,
      'catering_service' => Icons.room_service,
      'government_services' => Icons.account_balance,
      'insurance' => Icons.verified_user,
      'tech_repair' => Icons.phone_iphone,
      _ => Icons.miscellaneous_services,
    };
  }

  Widget _serviceDirectory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(t('أقسام الخدمات', 'Service categories')),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: serviceSubtypes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.92,
          ),
          itemBuilder: (context, index) {
            final option = serviceSubtypes[index];
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServicesScreen(
                      isArabic: isArabic,
                      isDark: isDark,
                      initialSubCategory: option.value,
                      initialTitleAr: option.ar,
                      initialTitleEn: option.en,
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
                      _serviceIcon(option.value),
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
                    _serviceSubtypeCountBadge(option.value),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _serviceSubtypeCountBadge(String subtype) {
    final stream = FirebaseFirestore.instance
        .collection('ads')
        .where('status', isEqualTo: 'approved')
        .where('category', isEqualTo: 'خدمة')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final count = docs.where((doc) {
          final data = doc.data();
          if (subtype == 'catering_service') {
            return data['subCategory']?.toString() == subtype ||
                _isCateringService(data);
          }
          if (subtype == 'government_services') {
            return data['subCategory']?.toString() == subtype ||
                _isGovernmentService(data);
          }
          if (subtype == 'insurance') {
            return data['subCategory']?.toString() == subtype ||
                _isInsuranceService(data);
          }
          if (subtype != 'other') {
            return data['subCategory']?.toString() == subtype;
          }

          if (_isKnownServiceAlias(data)) return false;

          final subCategory = data['subCategory']?.toString().trim() ?? '';
          final labelAr = data['subCategoryLabelAr']?.toString().trim() ?? '';
          final labelEn = data['subCategoryLabelEn']?.toString().trim() ?? '';
          return subCategory.isEmpty ||
              subCategory == 'other' ||
              labelAr == 'خدمة أخرى' ||
              labelEn.toLowerCase() == 'other service' ||
              !serviceSubtypeValues.contains(subCategory);
        }).length;
        return Text(
          isArabic ? '$count خدمة' : '$count services',
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey.shade600,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
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

  Widget _filterPanel(String title) {
    return SectionFilterPanel(
      isArabic: isArabic,
      isDark: isDark,
      title: title,
      searchHint: t('ابحث عن خدمة', 'Search service'),
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
      extraFilter: !isSubCategoryPage ? _subCategoryDropdown() : null,
    );
  }

  Widget _subCategoryDropdown() {
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
            t('كل الخدمات', 'All services'),
            style: const TextStyle(color: Colors.grey),
          ),
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text(
                t('كل الخدمات', 'All services'),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
            ),
            ...serviceSubtypes.map(
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
}

Widget _serviceCard({
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
}) {
  final subtitle = description.isEmpty
      ? (isArabic ? 'تفاصيل الخدمة' : 'Service details')
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
                  label: isArabic ? 'رسالة' : 'SMS',
                  onPressed: () =>
                      AdActions.sendSms(context, phone, isArabic: isArabic),
                ),
              if (allowInAppMessage)
                ContactActionData(
                  color: Colors.blueGrey,
                  icon: Icons.chat,
                  label: isArabic ? 'التطبيق' : 'App',
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
