class CategorySubtypeOption {
  final String value;
  final String ar;
  final String en;

  const CategorySubtypeOption({
    required this.value,
    required this.ar,
    required this.en,
  });
}

const restaurantCategory = 'مطاعم';
const storesCategory = 'محلات تجارية';
const legacyRestaurantStoreCategory = 'مطاعم ومحلات';

const serviceSubtypes = [
  CategorySubtypeOption(value: 'plumbing', ar: 'سباك', en: 'Plumber'),
  CategorySubtypeOption(value: 'electrician', ar: 'كهربائي', en: 'Electrician'),
  CategorySubtypeOption(value: 'carpenter', ar: 'نجار', en: 'Carpenter'),
  CategorySubtypeOption(value: 'cleaning', ar: 'تنظيف', en: 'Cleaning'),
  CategorySubtypeOption(value: 'painting', ar: 'دهان', en: 'Painting'),
  CategorySubtypeOption(value: 'moving', ar: 'نقل وعفش', en: 'Moving'),
  CategorySubtypeOption(
    value: 'ac_repair',
    ar: 'تبريد وتكييف',
    en: 'AC repair',
  ),
  CategorySubtypeOption(
    value: 'camera_security',
    ar: 'كاميرات وأمن',
    en: 'Cameras & security',
  ),
  CategorySubtypeOption(
    value: 'taxes',
    ar: 'ضرائب ومحاسبة',
    en: 'Taxes & accounting',
  ),
  CategorySubtypeOption(value: 'notary', ar: 'كاتب عدل', en: 'Notary'),
  CategorySubtypeOption(value: 'translation', ar: 'ترجمة', en: 'Translation'),
  CategorySubtypeOption(value: 'beauty', ar: 'تجميل', en: 'Beauty'),
  CategorySubtypeOption(value: 'education', ar: 'تعليم ودروس', en: 'Education'),
  CategorySubtypeOption(
    value: 'catering_service',
    ar: 'كاترينج',
    en: 'Catering',
  ),
  CategorySubtypeOption(
    value: 'government_services',
    ar: 'معاملات حكومية',
    en: 'Government services',
  ),
  CategorySubtypeOption(value: 'insurance', ar: 'تأمين', en: 'Insurance'),
  CategorySubtypeOption(
    value: 'tech_repair',
    ar: 'كمبيوتر وجوالات',
    en: 'Tech repair',
  ),
  CategorySubtypeOption(value: 'other', ar: 'خدمة أخرى', en: 'Other service'),
];

const restaurantSubtypes = [
  CategorySubtypeOption(value: 'restaurant', ar: 'مطعم', en: 'Restaurant'),
  CategorySubtypeOption(value: 'cafe', ar: 'كافيه', en: 'Cafe'),
  CategorySubtypeOption(value: 'sweets', ar: 'حلويات', en: 'Sweets'),
  CategorySubtypeOption(value: 'bakery', ar: 'مخبز', en: 'Bakery'),
  CategorySubtypeOption(value: 'catering', ar: 'كاترينغ', en: 'Catering'),
  CategorySubtypeOption(
    value: 'hookah',
    ar: 'أركيلة ولاونج',
    en: 'Hookah lounge',
  ),
  CategorySubtypeOption(value: 'other', ar: 'غير ذلك', en: 'Other'),
];

const storeSubtypes = [
  CategorySubtypeOption(value: 'market', ar: 'ماركت عربي', en: 'Arab market'),
  CategorySubtypeOption(value: 'phone_store', ar: 'جوالات', en: 'Phone store'),
  CategorySubtypeOption(value: 'clothing', ar: 'ملابس', en: 'Clothing'),
  CategorySubtypeOption(value: 'jewelry', ar: 'ذهب ومجوهرات', en: 'Jewelry'),
  CategorySubtypeOption(value: 'furniture', ar: 'مفروشات', en: 'Furniture'),
  CategorySubtypeOption(value: 'roastery', ar: 'محمصة', en: 'Roastery'),
  CategorySubtypeOption(
    value: 'beauty_store',
    ar: 'تجميل وعطور',
    en: 'Beauty & perfume',
  ),
  CategorySubtypeOption(
    value: 'auto_parts',
    ar: 'قطع سيارات',
    en: 'Auto parts',
  ),
  CategorySubtypeOption(value: 'other', ar: 'محل آخر', en: 'Other store'),
];

const legalSubtypes = [
  CategorySubtypeOption(value: 'immigration', ar: 'هجرة', en: 'Immigration'),
  CategorySubtypeOption(
    value: 'accident',
    ar: 'حوادث وإصابات',
    en: 'Accidents',
  ),
  CategorySubtypeOption(value: 'family', ar: 'عائلة وطلاق', en: 'Family law'),
  CategorySubtypeOption(
    value: 'business',
    ar: 'أعمال وعقود',
    en: 'Business law',
  ),
  CategorySubtypeOption(
    value: 'consultation',
    ar: 'استشارة قانونية',
    en: 'Legal consultation',
  ),
  CategorySubtypeOption(value: 'notary', ar: 'كاتب عدل', en: 'Notary'),
  CategorySubtypeOption(value: 'other', ar: 'قانوني آخر', en: 'Other legal'),
];

List<CategorySubtypeOption> subtypesForCategory(String category) {
  return switch (category) {
    'خدمة' => serviceSubtypes,
    storesCategory => storeSubtypes,
    'محامين وهجرة' => legalSubtypes,
    _ => const [],
  };
}

String subtypeLabel(String value, bool isArabic) {
  for (final options in [
    serviceSubtypes,
    restaurantSubtypes,
    storeSubtypes,
    legalSubtypes,
  ]) {
    for (final option in options) {
      if (option.value == value || option.ar == value || option.en == value) {
        return isArabic ? option.ar : option.en;
      }
    }
  }
  return value;
}

bool isRestaurantCategory(String category) {
  return category == restaurantCategory ||
      category == legacyRestaurantStoreCategory;
}

bool isStoreCategory(String category) {
  return category == storesCategory;
}

bool isRestaurantOrStoreCategory(String category) {
  return isRestaurantCategory(category) || isStoreCategory(category);
}
