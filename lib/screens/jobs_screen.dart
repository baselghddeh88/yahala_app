import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'details_screen.dart';
import 'add_post_screen.dart';
import 'search_screen.dart';
import '../services/ad_actions.dart';
import '../utils/ad_promotion.dart';
import '../utils/value_formatters.dart';
import '../widgets/city_picker_field.dart';
import '../widgets/favorite_button.dart';
import '../widgets/paid_category_ads.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class JobsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;

  const JobsScreen({super.key, required this.isArabic, required this.isDark});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final queryController = TextEditingController();
  final cityController = TextEditingController();
  final zipController = TextEditingController();

  bool get isArabic => widget.isArabic;
  bool get isDark => widget.isDark;

  String query = '';
  String cityFilter = '';
  String zipFilter = '';

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
          elevation: 0,
          centerTitle: true,
          title: Text(
            t('وظائف', 'Jobs'),
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
              _searchBox(context, t('ابحث عن وظيفة...', 'Search jobs...')),

              const SizedBox(height: 16),
              _filterPanel(t('فلتر الوظائف', 'Jobs filter')),

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
                          initialCategory: 'وظيفة',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    t('أضف وظيفة', 'Add Job'),
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
                category: 'وظيفة',
                icon: Icons.work,
              ),

              const SizedBox(height: 22),

              _sectionTitle(t('آخر الوظائف', 'Latest Jobs')),

              const SizedBox(height: 12),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ads')
                    .where('category', isEqualTo: 'وظيفة')
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

                  final jobs = sortAdsByPromotion(
                    (snapshot.data?.docs ?? []).where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _matchesFilters(data);
                    }),
                  );

                  if (jobs.isEmpty) {
                    return Text(
                      t('لا توجد وظائف بعد', 'No jobs yet'),
                      style: const TextStyle(color: Colors.grey),
                    );
                  }

                  return Column(
                    children: jobs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      final title =
                          data['title']?.toString() ??
                          t('وظيفة بدون عنوان', 'Untitled Job');
                      final description = data['description']?.toString() ?? '';
                      final city = data['city']?.toString() ?? '';
                      final price = data['price']?.toString() ?? '';
                      final views = data['views']?.toString() ?? '0';
                      final imageUrl = data['imageUrl']?.toString() ?? '';
                      final imageUrls = List<String>.from(
                        data['imageUrls'] ?? [],
                      );
                      final phone = data['phone']?.toString() ?? '';

                      return _jobCard(
                        context: context,
                        adId: doc.id,
                        data: data,
                        isArabic: isArabic,
                        isDark: isDark,
                        title: title,
                        description: description,
                        city: city,
                        salary: price.isEmpty
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
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _filterInput(
            controller: queryController,
            hint: t('ابحث عن وظيفة', 'Search job'),
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
}

Widget _jobCard({
  required BuildContext context,
  required String adId,
  required Map<String, dynamic> data,
  required bool isArabic,
  required bool isDark,
  required String title,
  required String description,
  required String city,
  required String salary,
  required String views,
  required String imageUrl,
  required List<String> imageUrls,
  required String phone,
}) {
  final subtitle = description.isEmpty
      ? (isArabic ? 'تفاصيل الوظيفة' : 'Job details')
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
            price: salary,
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
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? bgDark : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.work, color: Colors.grey, size: 42),
            ),

          const SizedBox(height: 14),

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
                  salary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: yaHalaGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
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

          Row(
            children: [
              if (showCall)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: yaHalaGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () =>
                        AdActions.callPhone(context, phone, isArabic: isArabic),
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: Text(
                      isArabic ? 'اتصال' : 'Call',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),

              if (showCall && (showSms || allowInAppMessage))
                const SizedBox(width: 8),

              if (showSms)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: yaHalaGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () =>
                        AdActions.sendSms(context, phone, isArabic: isArabic),
                    icon: const Icon(Icons.sms, color: Colors.white),
                    label: Text(
                      isArabic ? 'رسالة' : 'SMS',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),

              if (showSms && allowInAppMessage) const SizedBox(width: 8),

              if (allowInAppMessage)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
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
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: Text(
                      isArabic ? 'التطبيق' : 'App',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),

              const SizedBox(width: 6),

              FavoriteButton(adId: adId, data: data, isArabic: isArabic),
            ],
          ),
        ],
      ),
    ),
  );
}
