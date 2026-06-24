import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ad_details_screen.dart';
import '../utils/ad_promotion.dart';
import '../utils/category_subtypes.dart';
import '../utils/service_category_suggestions.dart';
import '../widgets/city_picker_field.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class SearchScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;

  const SearchScreen({super.key, required this.isArabic, required this.isDark});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController();
  final cityController = TextEditingController();

  String query = '';
  String selectedCategory = '';
  String selectedSubtype = '';
  String selectedCity = '';

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void dispose() {
    searchController.dispose();
    cityController.dispose();
    super.dispose();
  }

  bool matchesFilters(Map<String, dynamic> data) {
    final title = data['title']?.toString().toLowerCase() ?? '';
    final desc = data['description']?.toString().toLowerCase() ?? '';
    final city = data['city']?.toString() ?? '';
    final category = data['category']?.toString() ?? '';
    final subCategory = [
      data['subCategory'],
      data['subCategoryLabelAr'],
      data['subCategoryLabelEn'],
    ].whereType<Object>().join(' ').toLowerCase();

    final textMatches =
        query.isEmpty ||
        title.contains(query) ||
        desc.contains(query) ||
        city.toLowerCase().contains(query) ||
        category.toLowerCase().contains(query) ||
        subCategory.contains(query);

    final categoryMatches =
        selectedCategory.isEmpty ||
        category == selectedCategory ||
        (selectedCategory == restaurantCategory &&
            category == legacyRestaurantStoreCategory);

    final cityMatches = selectedCity.isEmpty || city == selectedCity;
    final subtypeMatches =
        selectedSubtype.isEmpty ||
        data['subCategory']?.toString() == selectedSubtype ||
        subCategory.contains(selectedSubtype.toLowerCase());

    return textMatches && categoryMatches && subtypeMatches && cityMatches;
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
            t('البحث', 'Search'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: TextField(
                controller: searchController,
                autofocus: true,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: t('ابحث عن إعلان...', 'Search ads...'),
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: widget.isDark
                      ? cardColor
                      : const Color(0xFFF3F3F3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() => query = value.trim().toLowerCase());
                },
              ),
            ),

            _searchFilters(),

            const SizedBox(height: 10),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ads')
                    .where('status', isEqualTo: 'approved')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        snapshot.error.toString(),
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = sortAdsByPromotion(
                    snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return matchesFilters(data);
                    }),
                  );

                  if (query.isEmpty &&
                      selectedCategory.isEmpty &&
                      selectedSubtype.isEmpty &&
                      selectedCity.isEmpty) {
                    return Center(
                      child: Text(
                        t(
                          'اكتب كلمة أو اختر فلتر للبحث',
                          'Type something or choose a filter',
                        ),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        t('لا توجد نتائج', 'No results found'),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final title = data['title']?.toString() ?? '';
                      final city = data['city']?.toString() ?? '';
                      final category = data['category']?.toString() ?? '';
                      final imageUrl = data['imageUrl']?.toString() ?? '';

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdDetailsScreen(
                                isArabic: widget.isArabic,
                                isDark: widget.isDark,
                                data: data,
                                adId: doc.id,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? cardColor
                                : const Color(0xFFF3F3F3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              imageUrl.isEmpty
                                  ? Container(
                                      width: 70,
                                      height: 70,
                                      color: widget.isDark
                                          ? bgDark
                                          : Colors.white,
                                      child: const Icon(
                                        Icons.image,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : Image.network(
                                      imageUrl,
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                    ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title.isEmpty
                                          ? t('إعلان بدون عنوان', 'Untitled Ad')
                                          : title,
                                      style: TextStyle(
                                        color: widget.isDark
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      city.isEmpty
                                          ? category
                                          : '$category • $city',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required String value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: widget.isDark ? cardColor : Colors.white,
          hint: Text(hint, style: const TextStyle(color: Colors.grey)),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item.isEmpty ? hint : item,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _searchFilters() {
    return StreamBuilder<List<CategorySubtypeOption>>(
      stream: approvedServiceCategoriesStream(widget.isArabic),
      builder: (context, snapshot) {
        final subtypeOptions = _subtypeOptions(snapshot.data ?? const []);
        final selectedSubtypeValue =
            subtypeOptions.any((option) => option.value == selectedSubtype)
            ? selectedSubtype
            : '';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _filterDropdown(
                      value: selectedCategory,
                      hint: t('القسم', 'Category'),
                      items: const [
                        '',
                        'وظيفة',
                        'سكن',
                        'خدمة',
                        'كوبون',
                        'سؤال',
                        restaurantCategory,
                        storesCategory,
                        'فعاليات',
                        'محامين وهجرة',
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value ?? '';
                          selectedSubtype = '';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CityPickerField(
                      controller: cityController,
                      isArabic: widget.isArabic,
                      isDark: widget.isDark,
                      hint: t('المدينة', 'City'),
                      onSelected: (value) =>
                          setState(() => selectedCity = value),
                    ),
                  ),
                ],
              ),
              if (subtypeOptions.isNotEmpty) ...[
                const SizedBox(height: 10),
                _subtypeDropdown(subtypeOptions, selectedSubtypeValue),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _subtypeDropdown(
    List<CategorySubtypeOption> options,
    String selectedValue,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          dropdownColor: widget.isDark ? cardColor : Colors.white,
          hint: Text(
            t('التفريع', 'Subtype'),
            style: const TextStyle(color: Colors.grey),
          ),
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text(t('كل التفريعات', 'All subtypes')),
            ),
            ...options.map(
              (option) => DropdownMenuItem<String>(
                value: option.value,
                child: Text(widget.isArabic ? option.ar : option.en),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => selectedSubtype = value ?? '');
          },
        ),
      ),
    );
  }

  List<CategorySubtypeOption> _subtypeOptions(
    List<CategorySubtypeOption> dynamicServiceOptions,
  ) {
    return switch (selectedCategory) {
      'خدمة' => [...serviceSubtypes, ...dynamicServiceOptions],
      restaurantCategory => restaurantSubtypes,
      storesCategory => storeSubtypes,
      'محامين وهجرة' => legalSubtypes,
      _ => const [],
    };
  }
}
