import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'jobs_screen.dart';
import 'housing_screen.dart';
import 'services_screen.dart';
import 'coupons_screen.dart';
import 'community_screen.dart';
import 'chats_screen.dart';
import 'category_ads_screen.dart';
import 'add_post_screen.dart';
import 'admin_gate_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_choice_screen.dart';
import 'ad_details_screen.dart';
import 'search_screen.dart';
import '../constants.dart';
import '../services/app_settings.dart';
import '../widgets/favorite_button.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class HomeScreen extends StatefulWidget {
  final bool initialArabic;
  final bool initialDark;

  const HomeScreen({
    super.key,
    this.initialArabic = true,
    this.initialDark = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late bool isArabic;
  late bool isDark;
  int currentIndex = 0;
  final PageController _featuredPageController = PageController(
    viewportFraction: 0.92,
  );
  Timer? _featuredTimer;
  int _featuredIndex = 0;
  int _featuredAdsCount = 0;

  @override
  void initState() {
    super.initState();
    isArabic = widget.initialArabic;
    isDark = widget.initialDark;
    _startFeaturedAutoSlide();
  }

  @override
  void dispose() {
    _featuredTimer?.cancel();
    _featuredPageController.dispose();
    super.dispose();
  }

  void _startFeaturedAutoSlide() {
    _featuredTimer?.cancel();
    _featuredTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted ||
          !_featuredPageController.hasClients ||
          _featuredAdsCount <= 1) {
        return;
      }

      final nextIndex = (_featuredIndex + 1) % _featuredAdsCount;
      _featuredPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: yahalaPageBg(isDark),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: isDark ? const Color(0xFF101B28) : yaHalaGreen,
          elevation: 0,
          centerTitle: true,
          title: GestureDetector(
            onLongPress: _showAdminPasswordDialog,
            child: Text(
              t('يا هلا', 'Yahala'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {
                setState(() => isDark = !isDark);
                AppSettings.save(isArabic: isArabic, isDark: isDark);
              },
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: Colors.white,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => isArabic = !isArabic);
                AppSettings.save(isArabic: isArabic, isDark: isDark);
              },
              child: Text(
                isArabic ? 'EN' : 'عربي',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: currentIndex == 0 ? _homeBody() : _navPlaceholder(),
        bottomNavigationBar: _buildEnhancedBottomNav(),
      ),
    );
  }

  Widget _homeBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(
              'يا هلا جريدة العرب الرقمية',
              'Arab Digital Newspaper in California',
            ),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: yahalaText(isDark),
            ),
          ),
          const SizedBox(height: 14),
          _buildSearchBox(),
          const SizedBox(height: 20),
          _adSectionHeader(
            title: t('إعلانات VIP', 'VIP Ads'),
            subtitle: t(
              'أقوى إعلان أعلى الصفحة - 1200×540',
              'Top premium spot - 1200x540',
            ),
            placement: 'vip_slider',
          ),
          const SizedBox(height: 10),
          _buildHomeSlider(),
          const SizedBox(height: 22),
          _adSectionHeader(
            title: t('إعلانات مميزة', 'Featured Ads'),
            subtitle: t(
              'ظهور مميز تحت VIP - 900×500',
              'Featured placement below VIP - 900x500',
            ),
            placement: 'featured',
          ),
          const SizedBox(height: 10),
          _buildFeaturedAds(),
          const SizedBox(height: 22),
          _sectionTitle(t('الأقسام', 'Categories')),
          const SizedBox(height: 12),
          _buildCategoriesGrid(),
          const SizedBox(height: 24),
          _sectionTitle(t('آخر الإعلانات', 'Latest Ads')),
          const SizedBox(height: 10),
          _latestAdsFromFirebase(),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchScreen(isArabic: isArabic, isDark: isDark),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? cardColor : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t(
                  'ابحث عن وظيفة، سكن، خدمة...',
                  'Search jobs, housing, services...',
                ),
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeSlider() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('homeSlides').snapshots(),
      builder: (context, slidesSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('ads')
              .where('status', isEqualTo: 'approved')
              .where('adPlacement', isEqualTo: 'vip_slider')
              .snapshots(),
          builder: (context, adsSnapshot) {
            if (!slidesSnapshot.hasData || !adsSnapshot.hasData) {
              return const SizedBox(
                height: 190,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(yaHalaGreen),
                  ),
                ),
              );
            }

            final slides = <Map<String, dynamic>>[];

            for (final doc in adsSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              if ((data['imageUrl']?.toString() ?? '').isNotEmpty) {
                slides.add({...data, 'adId': doc.id});
              }
            }

            final adminSlides = slidesSnapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['active'] != false &&
                  (data['imageUrl']?.toString() ?? '').isNotEmpty;
            }).toList();

            adminSlides.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aSort = aData['sort'];
              final bSort = bData['sort'];
              return (aSort is int ? aSort : 0).compareTo(
                bSort is int ? bSort : 0,
              );
            });

            for (final doc in adminSlides) {
              slides.add(doc.data() as Map<String, dynamic>);
            }

            _featuredAdsCount = slides.isEmpty ? 1 : slides.length;

            if (_featuredIndex >= _featuredAdsCount) {
              _featuredIndex = 0;
            }

            return Column(
              children: [
                SizedBox(
                  height: 190,
                  child: slides.isEmpty
                      ? PageView(
                          controller: _featuredPageController,
                          children: [_featuredBookingCard()],
                        )
                      : PageView.builder(
                          controller: _featuredPageController,
                          itemCount: slides.length,
                          onPageChanged: (index) {
                            setState(() => _featuredIndex = index);
                          },
                          itemBuilder: (context, index) {
                            return _homeSlideCard(slides[index]);
                          },
                        ),
                ),
                const SizedBox(height: 10),
                _featuredDots(_featuredAdsCount),
              ],
            );
          },
        );
      },
    );
  }

  Widget _homeSlideCard(Map<String, dynamic> data) {
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final adId = data['adId']?.toString() ?? '';

    return GestureDetector(
      onTap: imageUrl.isEmpty
          ? null
          : () {
              if (adId.isNotEmpty) {
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
                return;
              }

              _openSlideImage(imageUrl);
            },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? cardColor : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Transform.scale(
                  scale: 1.12,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: isDark ? cardColor : const Color(0xFFF3F3F3),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.22),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: 16,
              bottom: 16,
              child: _sponsoredBadge(),
            ),
            PositionedDirectional(
              end: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
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
      ),
    );
  }

  void _openSlideImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SlideImageViewer(
          imageUrl: imageUrl,
          isArabic: isArabic,
          isDark: isDark,
        ),
      ),
    );
  }

  Widget _buildFeaturedAds() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .where('status', isEqualTo: 'approved')
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 150,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(yaHalaGreen),
              ),
            ),
          );
        }

        final ads = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isFeatured'] == true;
        }).toList();

        if (ads.isEmpty) {
          return _featuredMiniPlaceholder();
        }

        return SizedBox(
          height: 122,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final doc = ads[index];
              final data = doc.data() as Map<String, dynamic>;
              return SizedBox(
                width: 230,
                child: _featuredMiniAdCard(doc.id, data),
              );
            },
          ),
        );
      },
    );
  }

  Widget _featuredMiniAdCard(String id, Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? '';
    final subtitle = (data['price']?.toString() ?? '').isNotEmpty
        ? data['price'].toString()
        : (data['city']?.toString() ?? '');
    final imageUrl = data['imageUrl']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdDetailsScreen(
              isArabic: isArabic,
              isDark: isDark,
              data: data,
              adId: id,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? cardColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 66,
              height: 66,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: yaHalaGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: imageUrl.isEmpty
                  ? const Icon(Icons.star, color: yaHalaGold)
                  : Image.network(imageUrl, fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? t('إعلان مميز', 'Featured ad') : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: yahalaText(isDark),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: yaHalaGold,
                        fontWeight: FontWeight.bold,
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

  Widget _featuredMiniPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: yaHalaGold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.star, color: yaHalaGold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t('لا يوجد إعلانات مميزة حالياً', 'No featured ads right now'),
              style: TextStyle(
                color: yahalaText(isDark),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featuredBookingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [yaHalaGreen, yaHalaGold.withValues(alpha: 0.9)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: yaHalaGreen.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _sponsoredBadge(),
                const SizedBox(height: 14),
                Text(
                  t('احجز مكان إعلانك هنا', 'Reserve your featured spot'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'مساحة مميزة للإعلانات المدفوعة قريبًا',
                    'Premium paid ads space coming soon',
                  ),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.campaign, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _sponsoredBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        t('إعلان ممول', 'Sponsored'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _featuredDots(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == _featuredIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: active ? 18 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active
                ? yaHalaGold
                : (isDark ? Colors.white24 : Colors.black12),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }

  Widget _buildCategoriesGrid() {
    final isTablet = MediaQuery.of(context).size.width > 700;

    final categories = [
      {
        'icon': Icons.work,
        'label': t('وظائف', 'Jobs'),
        'count': '124',
        'color': yaHalaGreen,
        'screen': JobsScreen(isArabic: isArabic, isDark: isDark),
      },
      {
        'icon': Icons.home,
        'label': t('سكن', 'Housing'),
        'count': '87',
        'color': yaHalaGold,
        'screen': HousingScreen(isArabic: isArabic, isDark: isDark),
      },
      {
        'icon': Icons.handyman,
        'label': t('خدمات', 'Services'),
        'count': '96',
        'color': yaHalaGreen,
        'screen': ServicesScreen(isArabic: isArabic, isDark: isDark),
      },
      {
        'icon': Icons.local_offer,
        'label': t('كوبونات', 'Coupons'),
        'count': '43',
        'color': yaHalaGold,
        'screen': CouponsScreen(isArabic: isArabic, isDark: isDark),
      },
      {
        'icon': Icons.forum,
        'label': t('اسأل الجالية', 'Ask Community'),
        'count': '156',
        'color': yaHalaGreen,
        'screen': CommunityScreen(isArabic: isArabic, isDark: isDark),
      },
      _genericCategory(
        icon: Icons.restaurant,
        labelAr: 'مطاعم ومحلات عربية',
        labelEn: 'Arab Restaurants & Stores',
        category: 'مطاعم ومحلات',
        color: yaHalaGold,
      ),
      _genericCategory(
        icon: Icons.event,
        labelAr: 'فعاليات ومناسبات',
        labelEn: 'Events',
        category: 'فعاليات',
        color: yaHalaGreen,
      ),
      _genericCategory(
        icon: Icons.gavel,
        labelAr: 'محامين وهجرة',
        labelEn: 'Lawyers & Immigration',
        category: 'محامين وهجرة',
        color: yaHalaGreen,
      ),
      {
        'icon': Icons.add_circle_outline,
        'label': t('أضف إعلان', 'Add Post'),
        'count': '➕',
        'color': yaHalaGold,
        'screen': AddPostScreen(isArabic: isArabic, isDark: isDark),
      },
    ];

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isTablet ? 2.1 : 1.35,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => cat['screen'] as Widget),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? cardColor : const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  cat['icon'] as IconData,
                  color: cat['color'] as Color,
                  size: 34,
                ),
                const SizedBox(height: 10),
                Text(
                  cat['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cat['count'] as String,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, Object> _genericCategory({
    required IconData icon,
    required String labelAr,
    required String labelEn,
    required String category,
    required Color color,
  }) {
    return {
      'icon': icon,
      'label': t(labelAr, labelEn),
      'count': t('جديد', 'New'),
      'color': color,
      'screen': CategoryAdsScreen(
        isArabic: isArabic,
        isDark: isDark,
        category: category,
        titleAr: labelAr,
        titleEn: labelEn,
        icon: icon,
      ),
    };
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }

  Widget _adSectionHeader({
    required String title,
    required String subtitle,
    required String placement,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: yahalaText(isDark),
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: yaHalaGreen,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onPressed: () => _openPaidAdRequest(placement),
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: Text(
            t('أضف', 'Add'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  void _openPaidAdRequest(String placement) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPostScreen(
          isArabic: isArabic,
          isDark: isDark,
          initialCategory: 'إعلان مدفوع',
          initialAdPlacement: placement,
        ),
      ),
    );
  }

  Widget _latestAdsFromFirebase() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .where('status', isEqualTo: 'approved')
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final ads = snapshot.data!.docs;

        if (ads.isEmpty) {
          return Text(
            t('لا توجد إعلانات بعد', 'No ads yet'),
            style: const TextStyle(color: Colors.grey),
          );
        }

        return Column(
          children: ads.map((doc) {
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
                      isArabic: isArabic,
                      isDark: isDark,
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
                  color: isDark ? cardColor : const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    imageUrl.isEmpty
                        ? Container(
                            width: 80,
                            height: 80,
                            color: isDark ? bgDark : Colors.white,
                            child: const Icon(Icons.image, color: Colors.grey),
                          )
                        : Image.network(
                            imageUrl,
                            width: 80,
                            height: 80,
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                city.isEmpty ? category : city,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              FavoriteButton(
                                adId: doc.id,
                                data: data,
                                isArabic: isArabic,
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
          }).toList(),
        );
      },
    );
  }

  Widget _buildEnhancedBottomNav() {
    final items = [
      {'icon': Icons.home, 'index': 0},
      {'icon': Icons.favorite, 'index': 1},
      {'icon': Icons.add_circle_outline, 'index': 2},
      {'icon': Icons.forum, 'index': 3},
      {'icon': Icons.person, 'index': 4},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111e2d) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE6E8E2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            final index = item['index'] as int;
            final active = currentIndex == index;

            return IconButton(
              onPressed: () {
                if (index == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddPostScreen(isArabic: isArabic, isDark: isDark),
                    ),
                  );
                } else {
                  setState(() => currentIndex = index);
                }
              },
              icon: _bottomNavIcon(item['icon'] as IconData, active, index),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _bottomNavIcon(IconData icon, bool active, int index) {
    final baseIcon = Icon(icon, color: active ? yaHalaGreen : Colors.grey);

    if (index != 3) return baseIcon;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return baseIcon;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participantIds', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount =
            snapshot.data?.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _hasUnreadChat(data, user.uid);
            }).length ??
            0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            baseIcon,
            if (unreadCount > 0)
              PositionedDirectional(
                top: -9,
                end: -11,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF111e2d) : Colors.white,
                      width: 1.8,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _hasUnreadChat(Map<String, dynamic> data, String userId) {
    final unread = Map<String, dynamic>.from(data['unreadBy'] ?? {});
    if (_isUnreadValue(unread[userId])) return true;

    final lastSenderId = data['lastSenderId']?.toString();
    final updatedAt = data['updatedAt'];
    if (lastSenderId == null ||
        lastSenderId == userId ||
        updatedAt is! Timestamp) {
      return false;
    }

    final reads = Map<String, dynamic>.from(data['lastReadAt'] ?? {});
    final lastReadAt = reads[userId];
    return lastReadAt is! Timestamp ||
        lastReadAt.millisecondsSinceEpoch < updatedAt.millisecondsSinceEpoch;
  }

  bool _isUnreadValue(dynamic value) {
    return value == true || value == 'true' || value == 1;
  }

  Widget _navPlaceholder() {
    if (currentIndex == 1) {
      return FavoritesScreen(isArabic: isArabic, isDark: isDark);
    }

    if (currentIndex == 3) {
      return ChatsScreen(isArabic: isArabic, isDark: isDark, showAppBar: false);
    }

    if (currentIndex == 4) {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return AuthChoiceScreen(isArabic: isArabic, isDark: isDark);
      }

      return ProfileScreen(
        isArabic: isArabic,
        isDark: isDark,
        showAppBar: false,
      );
    }

    return Center(
      child: Text(
        currentIndex == 1
            ? t('المفضلة', 'Favorites')
            : currentIndex == 3
            ? t('المحادثات', 'Chats')
            : t('حسابي', 'Profile'),
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  void _showAdminPasswordDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminGateScreen(isArabic: isArabic, isDark: isDark),
      ),
    );
  }
}

class _SlideImageViewer extends StatelessWidget {
  final String imageUrl;
  final bool isArabic;
  final bool isDark;

  const _SlideImageViewer({
    required this.imageUrl,
    required this.isArabic,
    required this.isDark,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? bgDark : Colors.black,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF101B28) : yaHalaGreen,
          elevation: 0,
          centerTitle: true,
          title: Text(
            t('الإعلان', 'Ad'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Transform.scale(
                  scale: 1.16,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Colors.black),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.white,
                          size: 56,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
