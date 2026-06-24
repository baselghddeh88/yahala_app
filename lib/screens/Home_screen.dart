import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
import '../utils/ad_promotion.dart';
import '../utils/category_subtypes.dart';
import '../utils/service_category_suggestions.dart';
import '../utils/value_formatters.dart';
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

class _HomeFilterOption {
  final String value;
  final String label;

  const _HomeFilterOption(this.value, this.label);
}

class _HomeScreenState extends State<HomeScreen> {
  late bool isArabic;
  late bool isDark;
  int currentIndex = 0;
  final PageController _featuredPageController = PageController(
    viewportFraction: 0.92,
  );
  final PageController _featuredAdsPageController = PageController();
  Timer? _featuredTimer;
  Timer? _featuredAdsTimer;
  StreamSubscription<List<CategorySubtypeOption>>?
  _dynamicServiceCategoriesSubscription;
  int _featuredIndex = 0;
  int _featuredAdsCount = 0;
  int _featuredMiniIndex = 0;
  int _featuredMiniCount = 0;
  String homeCategoryFilter = '';
  String homeSubtypeFilter = '';
  List<CategorySubtypeOption> dynamicHomeServiceSubtypes = const [];

  @override
  void initState() {
    super.initState();
    isArabic = widget.initialArabic;
    isDark = widget.initialDark;
    _startFeaturedAutoSlide();
    _startFeaturedAdsAutoSlide();
    _dynamicServiceCategoriesSubscription =
        approvedServiceCategoriesStream(isArabic).listen((options) {
          if (!mounted) return;
          setState(() => dynamicHomeServiceSubtypes = options);
        });
  }

  @override
  void dispose() {
    _featuredTimer?.cancel();
    _featuredAdsTimer?.cancel();
    _dynamicServiceCategoriesSubscription?.cancel();
    _featuredPageController.dispose();
    _featuredAdsPageController.dispose();
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

  void _startFeaturedAdsAutoSlide() {
    _featuredAdsTimer?.cancel();
    _featuredAdsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted ||
          !_featuredAdsPageController.hasClients ||
          _featuredMiniCount <= 1) {
        return;
      }

      final nextIndex = (_featuredMiniIndex + 1) % _featuredMiniCount;
      _featuredAdsPageController.animateToPage(
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
          _homeLatestFilter(),
          const SizedBox(height: 12),
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

            final vipAds = sortAdsByPromotion(adsSnapshot.data!.docs).take(5);
            for (final doc in vipAds) {
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
          .limit(150)
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

        final ads = sortPaidAdsByPromotion(
          snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final placement = data['adPlacement']?.toString() ?? '';
            return placement == featuredHomeAdPlacement ||
                data['paidAdType'] == 'featured' ||
                isFeaturedAd(data);
          }),
        ).take(10).toList();

        if (ads.isEmpty) {
          _featuredMiniCount = 0;
          _featuredMiniIndex = 0;
          return _featuredMiniPlaceholder();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final adsPerPage = constraints.maxWidth >= 700 ? 3 : 2;
            final pageCount = (ads.length / adsPerPage).ceil();

            _featuredMiniCount = pageCount;
            if (_featuredMiniIndex >= _featuredMiniCount) {
              _featuredMiniIndex = 0;
            }

            return Column(
              children: [
                SizedBox(
                  height: 142,
                  child: PageView.builder(
                    controller: _featuredAdsPageController,
                    itemCount: pageCount,
                    onPageChanged: (index) {
                      setState(() => _featuredMiniIndex = index);
                    },
                    itemBuilder: (context, pageIndex) {
                      final start = pageIndex * adsPerPage;
                      final pageAds = ads.skip(start).take(adsPerPage).toList();

                      return Row(
                        children: [
                          for (var index = 0; index < adsPerPage; index++) ...[
                            Expanded(
                              child: index < pageAds.length
                                  ? _featuredMiniAdCard(
                                      pageAds[index].id,
                                      pageAds[index].data()
                                          as Map<String, dynamic>,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            if (index != adsPerPage - 1)
                              const SizedBox(width: 10),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                if (_featuredMiniCount > 1) ...[
                  const SizedBox(height: 10),
                  _dots(_featuredMiniCount, _featuredMiniIndex),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _featuredMiniAdCard(String id, Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? '';
    final rawPrice = data['price']?.toString() ?? '';
    final subtitle = rawPrice.isNotEmpty
        ? formatMoney(rawPrice)
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? cardColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: yaHalaGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: imageUrl.isEmpty
                    ? const Icon(Icons.star, color: yaHalaGold)
                    : Image.network(imageUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title.isEmpty ? t('إعلان مميز', 'Featured ad') : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: yahalaText(isDark),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: yaHalaGold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
    return _dots(count, _featuredIndex);
  }

  Widget _dots(int count, int activeIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == activeIndex;

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
        ..._genericCategory(
          icon: Icons.work,
          labelAr: 'وظائف',
          labelEn: 'Jobs',
          category: 'وظيفة',
          color: yaHalaGreen,
        ),
      },
      {
        ..._genericCategory(
          icon: Icons.home,
          labelAr: 'سكن',
          labelEn: 'Housing',
          category: 'سكن',
          color: yaHalaGold,
        ),
      },
      {
        'icon': Icons.handyman,
        'label': t('خدمات', 'Services'),
        'color': yaHalaGreen,
        'screen': ServicesScreen(isArabic: isArabic, isDark: isDark),
      },
      {
        'icon': Icons.local_offer,
        'label': t('كوبونات', 'Coupons'),
        'color': yaHalaGold,
        'screen': CouponsScreen(isArabic: isArabic, isDark: isDark),
      },
      {
        'icon': Icons.forum,
        'label': t('اسأل الجالية', 'Ask Community'),
        'color': yaHalaGreen,
        'screen': CommunityScreen(isArabic: isArabic, isDark: isDark),
      },
      _genericCategory(
        icon: Icons.restaurant,
        labelAr: 'مطاعم وكافيهات',
        labelEn: 'Restaurants & Cafes',
        category: restaurantCategory,
        color: yaHalaGold,
      ),
      _genericCategory(
        icon: Icons.storefront,
        labelAr: 'محلات تجارية',
        labelEn: 'Stores',
        category: storesCategory,
        color: yaHalaGreen,
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
        Wrap(
          spacing: 2,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: yaHalaGold,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onPressed: () => _openPaidAdsList(placement, title),
              child: Text(
                t('إظهار الكل', 'View all'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openPaidAdsList(String placement, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaidAdsListScreen(
          isArabic: isArabic,
          isDark: isDark,
          placement: placement,
          title: title,
        ),
      ),
    );
  }

  Widget _latestAdsFromFirebase() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .where('status', isEqualTo: 'approved')
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final ads = sortAdsByPromotion(
          snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _matchesHomeLatestFilters(data);
          }),
        ).take(10).toList();

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

  Widget _homeLatestFilter() {
    final subtypes = _homeSubtypeOptions();
    final selectedSubtype =
        subtypes.any((option) => option.value == homeSubtypeFilter)
        ? homeSubtypeFilter
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final categoryDropdown = _homeDropdown(
            value: homeCategoryFilter.isEmpty ? null : homeCategoryFilter,
            hint: t('كل الأقسام', 'All categories'),
            items: _homeCategoryOptions()
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.value,
                    child: Text(item.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                homeCategoryFilter = value ?? '';
                homeSubtypeFilter = '';
              });
            },
          );

          final subtypeDropdown = _homeDropdown(
            value: selectedSubtype,
            hint: t('كل التفريعات', 'All subtypes'),
            items: subtypes
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option.value,
                    child: Text(isArabic ? option.ar : option.en),
                  ),
                )
                .toList(),
            onChanged: subtypes.isEmpty
                ? null
                : (value) {
                    setState(() => homeSubtypeFilter = value ?? '');
                  },
          );

          final clearButton =
              homeCategoryFilter.isEmpty && homeSubtypeFilter.isEmpty
              ? const SizedBox.shrink()
              : TextButton.icon(
                  onPressed: () {
                    setState(() {
                      homeCategoryFilter = '';
                      homeSubtypeFilter = '';
                    });
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(t('مسح', 'Clear')),
                );

          if (constraints.maxWidth < 430) {
            return Column(
              children: [
                categoryDropdown,
                const SizedBox(height: 10),
                subtypeDropdown,
                if (homeCategoryFilter.isNotEmpty ||
                    homeSubtypeFilter.isNotEmpty)
                  Align(
                    alignment: isArabic
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: clearButton,
                  ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: categoryDropdown),
              const SizedBox(width: 10),
              Expanded(child: subtypeDropdown),
              clearButton,
            ],
          );
        },
      ),
    );
  }

  Widget _homeDropdown({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? bgDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: yaHalaGreen),
          dropdownColor: isDark ? cardColor : Colors.white,
          hint: Text(hint, style: const TextStyle(color: Colors.grey)),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w800,
          ),
          items: [
            DropdownMenuItem<String>(value: '', child: Text(hint)),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<_HomeFilterOption> _homeCategoryOptions() {
    return [
      _HomeFilterOption('وظيفة', t('وظائف', 'Jobs')),
      _HomeFilterOption('سكن', t('سكن', 'Housing')),
      _HomeFilterOption('خدمة', t('خدمات', 'Services')),
      _HomeFilterOption(restaurantCategory, t('مطاعم وكافيهات', 'Restaurants')),
      _HomeFilterOption(storesCategory, t('محلات تجارية', 'Stores')),
      _HomeFilterOption('فعاليات', t('فعاليات ومناسبات', 'Events')),
      _HomeFilterOption('محامين وهجرة', t('محامين وهجرة', 'Lawyers')),
      _HomeFilterOption('كوبون', t('كوبونات', 'Coupons')),
    ];
  }

  List<CategorySubtypeOption> _homeSubtypeOptions() {
    return switch (homeCategoryFilter) {
      'خدمة' => [...serviceSubtypes, ...dynamicHomeServiceSubtypes],
      restaurantCategory => restaurantSubtypes,
      storesCategory => storeSubtypes,
      'محامين وهجرة' => legalSubtypes,
      _ => const [],
    };
  }

  bool _matchesHomeLatestFilters(Map<String, dynamic> data) {
    final category = data['category']?.toString() ?? '';
    if (homeCategoryFilter.isNotEmpty) {
      if (homeCategoryFilter == restaurantCategory) {
        if (!isRestaurantCategory(category)) return false;
      } else if (category != homeCategoryFilter) {
        return false;
      }
    }

    if (homeSubtypeFilter.isEmpty) return true;
    if (data['subCategory']?.toString() == homeSubtypeFilter) return true;

    final subtype = _homeSubtypeOptions().where(
      (option) => option.value == homeSubtypeFilter,
    );
    if (subtype.isEmpty) return false;

    final text = [
      data['title'],
      data['description'],
      data['subCategoryLabelAr'],
      data['subCategoryLabelEn'],
    ].whereType<Object>().join(' ').toLowerCase();

    return text.contains(subtype.first.ar.toLowerCase()) ||
        text.contains(subtype.first.en.toLowerCase());
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
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              final index = item['index'] as int;
              final active = currentIndex == index;

              if (index == 2) return _bottomAddButton();

              return IconButton(
                onPressed: () => setState(() => currentIndex = index),
                icon: _bottomNavIcon(item['icon'] as IconData, active, index),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _bottomAddButton() {
    return Transform.translate(
      offset: const Offset(0, -22),
      child: Semantics(
        button: true,
        label: t('أضف إعلان', 'Add Post'),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AddPostScreen(isArabic: isArabic, isDark: isDark),
              ),
            );
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: yaHalaGold,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: yaHalaGold.withValues(alpha: isDark ? 0.28 : 0.42),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 38),
          ),
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

class PaidAdsListScreen extends StatelessWidget {
  final bool isArabic;
  final bool isDark;
  final String placement;
  final String title;

  const PaidAdsListScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    required this.placement,
    required this.title,
  });

  bool get _isVip => placement == 'vip_slider';

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: yahalaPageBg(isDark),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF101B28) : yaHalaGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: _isVip ? _vipAdsBody() : _featuredAdsBody(),
      ),
    );
  }

  Widget _vipAdsBody() {
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
              return _loading();
            }

            final items = <Map<String, dynamic>>[];

            final vipAds = sortAdsByPromotion(adsSnapshot.data!.docs).take(5);
            for (final doc in vipAds) {
              final data = doc.data() as Map<String, dynamic>;
              if ((data['imageUrl']?.toString() ?? '').isNotEmpty) {
                items.add({...data, 'adId': doc.id, '_kind': 'ad'});
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
              items.add({
                ...(doc.data() as Map<String, dynamic>),
                '_kind': 'slide',
              });
            }

            return _adsGrid(context, items);
          },
        );
      },
    );
  }

  Widget _featuredAdsBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _loading();
        }

        final featured = sortPaidAdsByPromotion(
          snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final adPlacement = data['adPlacement']?.toString() ?? '';
            return adPlacement == featuredHomeAdPlacement ||
                data['paidAdType'] == 'featured' ||
                isFeaturedAd(data);
          }),
        ).take(10);

        final items = featured.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {...data, 'adId': doc.id, '_kind': 'ad'};
        }).toList();

        return _adsGrid(context, items);
      },
    );
  }

  Widget _loading() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(yaHalaGreen),
      ),
    );
  }

  Widget _adsGrid(BuildContext context, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _isVip
                ? t('لا يوجد إعلانات VIP حالياً', 'No VIP ads right now')
                : t(
                    'لا يوجد إعلانات مميزة حالياً',
                    'No featured ads right now',
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: yahalaMutedText(isDark),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        return GridView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 3 : 1,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: isWide ? 1.1 : 1.55,
          ),
          itemBuilder: (context, index) {
            return _paidAdCard(context, items[index]);
          },
        );
      },
    );
  }

  Widget _paidAdCard(BuildContext context, Map<String, dynamic> data) {
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final adId = data['adId']?.toString() ?? '';
    final rawTitle = data['title']?.toString() ?? '';
    final rawPrice = data['price']?.toString() ?? '';
    final city = data['city']?.toString() ?? '';
    final displayTitle = rawTitle.isEmpty
        ? (_isVip ? t('إعلان VIP', 'VIP ad') : t('إعلان مميز', 'Featured ad'))
        : rawTitle;
    final subtitle = rawPrice.isNotEmpty ? formatMoney(rawPrice) : city;

    return InkWell(
      onTap: () {
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

        if (imageUrl.isNotEmpty) {
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
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? cardColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageUrl.isEmpty
                        ? ColoredBox(
                            color: yaHalaGold.withValues(alpha: 0.12),
                            child: const Icon(
                              Icons.campaign,
                              color: yaHalaGold,
                              size: 46,
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: yaHalaGold.withValues(alpha: 0.12),
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 12,
                    start: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isVip ? yaHalaGold : yaHalaGreen,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        _isVip ? 'VIP' : t('مميز', 'Featured'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  if (imageUrl.isNotEmpty)
                    PositionedDirectional(
                      end: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(12),
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
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: yahalaText(isDark),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
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
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
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
