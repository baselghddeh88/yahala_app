import 'package:cloud_firestore/cloud_firestore.dart';

const int vipAdSlots = 5;
const int featuredAdSlots = 10;
const int categoryTopAdSlots = 10;

const String vipAdPlacement = 'vip_slider';
const String featuredHomeAdPlacement = 'featured';
const String categoryTopAdPlacement = 'category_top';

const List<int> adDurationOptionsDays = [7, 14, 30];

bool isFreePromotionCategory(String category) {
  return category == 'كوبون' || category == 'سؤال';
}

bool isHomeVipPlacement(Map<String, dynamic> data) {
  final placement = data['adPlacement']?.toString() ?? '';
  final paidType = data['paidAdType']?.toString().toLowerCase() ?? '';
  final promotion = data['promotionTier']?.toString().toLowerCase() ?? '';

  return placement == vipAdPlacement ||
      paidType == 'home_vip' ||
      promotion == 'home_vip';
}

int adPromotionTier(Map<String, dynamic> data) {
  final category = data['category']?.toString() ?? '';
  if (isFreePromotionCategory(category)) return 0;

  final placement = data['adPlacement']?.toString() ?? '';
  final paidType = data['paidAdType']?.toString().toLowerCase() ?? '';
  final promotion = data['promotionTier']?.toString().toLowerCase() ?? '';

  if (isHomeVipPlacement(data)) {
    return 3;
  }

  if (placement == featuredHomeAdPlacement ||
      paidType == 'featured' ||
      paidType == 'home_featured' ||
      promotion == 'featured' ||
      promotion == 'home_featured') {
    return 2;
  }

  if (placement == categoryTopAdPlacement ||
      paidType == 'category_top' ||
      promotion == 'category_top' ||
      data['isFeatured'] == true) {
    return 1;
  }

  final explicitTier = data['priorityTier'];
  if (explicitTier is int) return explicitTier;
  if (explicitTier is num) return explicitTier.toInt();

  return 0;
}

bool isVipAd(Map<String, dynamic> data) => adPromotionTier(data) >= 3;

bool isFeaturedAd(Map<String, dynamic> data) => adPromotionTier(data) == 2;

bool isCategoryTopAd(Map<String, dynamic> data) => adPromotionTier(data) == 1;

bool isPaidPlacementAd(Map<String, dynamic> data) => adPromotionTier(data) > 0;

bool isAdActiveForDisplay(Map<String, dynamic> data) {
  final activeUntil = data['activeUntil'];
  if (activeUntil is Timestamp) {
    return activeUntil.toDate().isAfter(DateTime.now());
  }
  if (activeUntil is DateTime) return activeUntil.isAfter(DateTime.now());
  return true;
}

DateTime adSortDate(Map<String, dynamic> data) {
  for (final key in ['approvedAt', 'updatedAt', 'createdAt']) {
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

int compareAdsNewestFirst(
  QueryDocumentSnapshot<Object?> a,
  QueryDocumentSnapshot<Object?> b,
) {
  final aData = a.data() as Map<String, dynamic>;
  final bData = b.data() as Map<String, dynamic>;
  return adSortDate(bData).compareTo(adSortDate(aData));
}

List<QueryDocumentSnapshot<Object?>> sortAdsByPromotion(
  Iterable<QueryDocumentSnapshot<Object?>> docs, {
  int vipLimit = vipAdSlots,
  int featuredLimit = featuredAdSlots,
  int categoryTopLimit = categoryTopAdSlots,
}) {
  final vip = <QueryDocumentSnapshot<Object?>>[];
  final featured = <QueryDocumentSnapshot<Object?>>[];
  final categoryTop = <QueryDocumentSnapshot<Object?>>[];
  final normal = <QueryDocumentSnapshot<Object?>>[];

  for (final doc in docs) {
    final data = doc.data() as Map<String, dynamic>;
    if (!isAdActiveForDisplay(data)) continue;
    final tier = adPromotionTier(data);
    if (tier >= 3) {
      vip.add(doc);
    } else if (tier == 2) {
      featured.add(doc);
    } else if (tier == 1) {
      categoryTop.add(doc);
    } else {
      normal.add(doc);
    }
  }

  vip.sort(compareAdsNewestFirst);
  featured.sort(compareAdsNewestFirst);
  categoryTop.sort(compareAdsNewestFirst);
  normal.sort(compareAdsNewestFirst);

  return [
    ...vip.take(vipLimit),
    ...featured.take(featuredLimit),
    ...categoryTop.take(categoryTopLimit),
    ...vip.skip(vipLimit),
    ...featured.skip(featuredLimit),
    ...categoryTop.skip(categoryTopLimit),
    ...normal,
  ];
}

List<QueryDocumentSnapshot<Object?>> sortPaidAdsByPromotion(
  Iterable<QueryDocumentSnapshot<Object?>> docs, {
  int vipLimit = vipAdSlots,
  int featuredLimit = featuredAdSlots,
  int categoryTopLimit = categoryTopAdSlots,
}) {
  return sortAdsByPromotion(
    docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return isPaidPlacementAd(data);
    }),
    vipLimit: vipLimit,
    featuredLimit: featuredLimit,
    categoryTopLimit: categoryTopLimit,
  );
}
