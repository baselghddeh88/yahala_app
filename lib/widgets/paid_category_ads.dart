import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/ad_details_screen.dart';

const Color _green = Color(0xFF1a6b3c);
const Color _gold = Color(0xFFc9952a);
const Color _darkBg = Color(0xFF0e1621);
const Color _darkCard = Color(0xFF1c2b3a);

class PaidCategoryAds extends StatelessWidget {
  final bool isArabic;
  final bool isDark;
  final String category;
  final IconData icon;

  const PaidCategoryAds({
    super.key,
    required this.isArabic,
    required this.isDark,
    required this.category,
    required this.icon,
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .where('category', isEqualTo: category)
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final featured = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isFeatured'] == true ||
              data['adPlacement'] == 'vip_slider' ||
              data['adPlacement'] == 'featured';
        }).toList();

        if (featured.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('مميز في هذا القسم', 'Featured in this section'),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
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
    final city = data['city']?.toString() ?? data['address']?.toString() ?? '';
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final vip = data['adPlacement'] == 'vip_slider';

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
          color: isDark ? _darkCard : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _gold.withValues(alpha: 0.35)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl.isEmpty
                ? ColoredBox(
                    color: isDark ? _darkBg : const Color(0xFFF3F3F3),
                    child: Icon(icon, color: Colors.grey, size: 44),
                  )
                : Image.network(imageUrl, fit: BoxFit.cover),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
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
                  color: vip ? _green : _gold,
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
}
