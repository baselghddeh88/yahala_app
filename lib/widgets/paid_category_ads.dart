import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/ad_details_screen.dart';
import '../utils/ad_promotion.dart';
import '../utils/value_formatters.dart';
import 'promoted_ad_frame.dart';

const Color _gold = Color(0xFFc9952a);
const Color _darkBg = Color(0xFF0e1621);
const Color _darkCard = Color(0xFF1c2b3a);

class PaidCategoryAds extends StatelessWidget {
  final bool isArabic;
  final bool isDark;
  final String category;
  final String? subCategory;
  final IconData icon;
  final bool requireSubCategory;

  const PaidCategoryAds({
    super.key,
    required this.isArabic,
    required this.isDark,
    required this.category,
    this.subCategory,
    required this.icon,
    this.requireSubCategory = false,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_featuredAds(context)],
    );
  }

  Widget _featuredAds(BuildContext context) {
    final selectedSubCategory = subCategory?.trim() ?? '';
    if (requireSubCategory && selectedSubCategory.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .where('category', isEqualTo: category)
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final featured = sortPaidAdsByPromotion(
          snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (!isCategoryTopAd(data)) return false;
            return selectedSubCategory.isEmpty ||
                data['subCategory']?.toString() == selectedSubCategory;
          }),
        ).take(categoryTopAdSlots).toList();

        if (featured.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('أولوية الظهور', 'Priority listings'),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: featured.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _featuredCard(context, doc.id, data);
                }).toList(),
              ),
            ],
          ),
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
    final description = data['description']?.toString() ?? '';
    final city = data['city']?.toString() ?? data['address']?.toString() ?? '';
    final rawPrice = data['price']?.toString() ?? '';
    final price = rawPrice.isEmpty ? '' : formatMoney(rawPrice);
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final trailingInfo = price.isNotEmpty ? price : city;

    return PromotedAdFrame(
      isDark: isDark,
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? _darkCard : const Color(0xFFF3F3F3),
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
                        color: isDark ? _darkBg : Colors.white,
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
                      title.isEmpty ? t('إعلان مميز', 'Featured ad') : title,
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
                        if (city.isNotEmpty && price.isNotEmpty)
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
                        if (city.isNotEmpty && price.isNotEmpty)
                          const SizedBox(width: 8),
                        if (trailingInfo.isNotEmpty)
                          Flexible(
                            child: Text(
                              trailingInfo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                color: _gold,
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
      ),
    );
  }
}
