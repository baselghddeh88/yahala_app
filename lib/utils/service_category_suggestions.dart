import 'package:cloud_firestore/cloud_firestore.dart';

import 'category_subtypes.dart';

const int serviceCategorySuggestionThreshold = 5;

String normalizeServiceCategoryName(String input) {
  final normalized = input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9\s]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (normalized.isEmpty) return '';
  return normalized.replaceAll(' ', '_');
}

String cleanServiceCategoryLabel(String input) {
  return input.trim().replaceAll(RegExp(r'\s+'), ' ');
}

bool isBuiltInServiceSubtype(String value) {
  return serviceSubtypes.any(
    (option) =>
        option.value == value || option.ar == value || option.en == value,
  );
}

CategorySubtypeOption serviceSubtypeFromDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
  bool isArabic,
) {
  final data = doc.data();
  final value = data['value']?.toString().trim().isNotEmpty == true
      ? data['value'].toString().trim()
      : doc.id;
  final labelAr = data['labelAr']?.toString().trim();
  final labelEn = data['labelEn']?.toString().trim();
  final fallback = data['label']?.toString().trim();

  return CategorySubtypeOption(
    value: value,
    ar: labelAr?.isNotEmpty == true ? labelAr! : fallback ?? value,
    en: labelEn?.isNotEmpty == true ? labelEn! : fallback ?? value,
  );
}

Stream<List<CategorySubtypeOption>> approvedServiceCategoriesStream(
  bool isArabic,
) {
  return FirebaseFirestore.instance
      .collection('serviceCategories')
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map((snapshot) {
        final options = snapshot.docs
            .map((doc) => serviceSubtypeFromDoc(doc, isArabic))
            .where((option) => !isBuiltInServiceSubtype(option.value))
            .toList();

        options.sort((a, b) {
          final left = isArabic ? a.ar : a.en;
          final right = isArabic ? b.ar : b.en;
          return left.compareTo(right);
        });

        return options;
      });
}

Future<void> trackOtherServiceCategorySuggestion({
  required String label,
  required String adId,
  required String userId,
}) async {
  final cleanLabel = cleanServiceCategoryLabel(label);
  final value = normalizeServiceCategoryName(cleanLabel);

  if (value.isEmpty || isBuiltInServiceSubtype(value)) return;

  final ref = FirebaseFirestore.instance
      .collection('serviceCategorySuggestions')
      .doc(value);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final snapshot = await transaction.get(ref);
    final data = snapshot.data() ?? <String, dynamic>{};
    final currentCount = data['count'];
    final count = currentCount is num ? currentCount.toInt() : 0;
    final nextCount = count + 1;
    final currentStatus = data['status']?.toString();
    final shouldRequestApproval =
        nextCount >= serviceCategorySuggestionThreshold &&
        (currentStatus == null ||
            currentStatus.isEmpty ||
            currentStatus == 'new' ||
            currentStatus == 'rejected');

    transaction.set(ref, {
      'value': value,
      'label': cleanLabel,
      'labelAr': cleanLabel,
      'labelEn': cleanLabel,
      'count': nextCount,
      'lastAdId': adId,
      'lastUserId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      if (shouldRequestApproval) ...{
        'status': 'pending',
        'threshold': serviceCategorySuggestionThreshold,
        'thresholdReachedAt': FieldValue.serverTimestamp(),
      } else if (!snapshot.exists) ...{
        'status': 'new',
        'threshold': serviceCategorySuggestionThreshold,
      },
    }, SetOptions(merge: true));
  });
}
