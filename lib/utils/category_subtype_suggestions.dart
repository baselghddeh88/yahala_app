import 'package:cloud_firestore/cloud_firestore.dart';

import 'category_subtypes.dart';

const int categorySubtypeSuggestionThreshold = 5;

String normalizeCategorySubtypeName(String input) {
  final normalized = input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9\s]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (normalized.isEmpty) return '';
  return normalized.replaceAll(' ', '_');
}

String cleanCategorySubtypeLabel(String input) {
  return input.trim().replaceAll(RegExp(r'\s+'), ' ');
}

bool isBuiltInSubtypeForCategory(String category, String value) {
  return subtypesForCategory(category).any(
    (option) =>
        option.value == value || option.ar == value || option.en == value,
  );
}

CategorySubtypeOption categorySubtypeFromDoc(
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

Stream<List<CategorySubtypeOption>> approvedCategorySubtypesStream(
  String category,
  bool isArabic,
) {
  return FirebaseFirestore.instance
      .collection('categorySubtypes')
      .where('category', isEqualTo: category)
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map((snapshot) {
        final options = snapshot.docs
            .map((doc) => categorySubtypeFromDoc(doc, isArabic))
            .where(
              (option) => !isBuiltInSubtypeForCategory(category, option.value),
            )
            .toList();

        options.sort((a, b) {
          final left = isArabic ? a.ar : a.en;
          final right = isArabic ? b.ar : b.en;
          return left.compareTo(right);
        });

        return options;
      });
}

Future<void> trackCategorySubtypeSuggestion({
  required String category,
  required String label,
  required String adId,
  required String userId,
}) async {
  final cleanLabel = cleanCategorySubtypeLabel(label);
  final value = normalizeCategorySubtypeName(cleanLabel);

  if (value.isEmpty || isBuiltInSubtypeForCategory(category, value)) return;

  final docId = '${category}_$value';
  final ref = FirebaseFirestore.instance
      .collection('categorySubtypeSuggestions')
      .doc(docId);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final snapshot = await transaction.get(ref);
    final data = snapshot.data() ?? <String, dynamic>{};
    final currentCount = data['count'];
    final count = currentCount is num ? currentCount.toInt() : 0;
    final nextCount = count + 1;
    final currentStatus = data['status']?.toString();
    final shouldRequestApproval =
        nextCount >= categorySubtypeSuggestionThreshold &&
        (currentStatus == null ||
            currentStatus.isEmpty ||
            currentStatus == 'new' ||
            currentStatus == 'rejected');

    transaction.set(ref, {
      'category': category,
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
        'threshold': categorySubtypeSuggestionThreshold,
        'thresholdReachedAt': FieldValue.serverTimestamp(),
      } else if (!snapshot.exists) ...{
        'status': 'new',
        'threshold': categorySubtypeSuggestionThreshold,
      },
    }, SetOptions(merge: true));
  });
}
