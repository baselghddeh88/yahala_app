import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../services/ai_description_service.dart';
import '../utils/ad_promotion.dart';
import '../utils/category_subtypes.dart';
import '../utils/service_category_suggestions.dart';
import '../utils/value_formatters.dart';
import '../widgets/city_picker_field.dart';
import '../widgets/safe_bottom_scroll_view.dart';
import 'add_question_screen.dart' as community_question;

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class AddPostScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;
  final String? initialCategory;
  final String? initialSubCategory;
  final String? initialAdPlacement;
  final bool publishImmediately;
  final bool createdByAdmin;

  const AddPostScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    this.initialCategory,
    this.initialSubCategory,
    this.initialAdPlacement,
    this.publishImmediately = false,
    this.createdByAdmin = false,
  });

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  late String selectedCategory;
  bool isLoading = false;
  bool _publishInFlight = false;
  bool isFormattingDescription = false;
  final scrollController = ScrollController();
  final postInformationKey = GlobalKey();

  final List<File> selectedImages = [];
  final ImagePicker picker = ImagePicker();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final cityController = TextEditingController();
  final addressController = TextEditingController();
  final zipController = TextEditingController();
  final phoneController = TextEditingController();
  final priceController = TextEditingController();
  final couponValueController = TextEditingController();
  final couponLimitController = TextEditingController();
  final couponTermsController = TextEditingController();
  bool allowCall = true;
  bool allowSms = true;
  bool allowInAppMessage = true;
  bool promoteInCategory = false;
  bool wantsRestaurantCoupon = false;
  String housingType = 'إيجار';
  String? selectedSubtype;
  String? selectedSubtypeLabelAr;
  String? selectedSubtypeLabelEn;
  String? couponType;
  String? adPlacement;
  int selectedDurationDays = 30;
  DateTime? couponEndDate;
  DateTime? eventDate;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  int get maxImages {
    if (isPaidAdRequest) return 1;
    return selectedCategory == 'سكن' ? 5 : 1;
  }

  bool get isCategoryLocked => widget.initialCategory != null;
  bool get isHousing => selectedCategory == 'سكن';
  bool get isRestaurantOrStore => isRestaurantOrStoreCategory(selectedCategory);
  bool get isCoupon => selectedCategory == 'كوبون';
  bool get hasSubtypeOptions =>
      subtypesForCategory(selectedCategory).isNotEmpty;
  bool get hasSelectedSubtype =>
      selectedSubtype != null && selectedSubtype!.isNotEmpty;
  bool get canPromoteWithoutSubtype => selectedCategory == 'محامين وهجرة';
  bool get canPromoteInCategory =>
      widget.initialAdPlacement == null &&
      !isFreePromotionCategory(selectedCategory) &&
      (!hasSubtypeOptions || hasSelectedSubtype || canPromoteWithoutSubtype);
  String? get effectiveAdPlacement => isFreePromotionCategory(selectedCategory)
      ? null
      : promoteInCategory
      ? categoryTopAdPlacement
      : adPlacement;
  bool get isPaidAdRequest => effectiveAdPlacement != null;
  bool get isVipAdRequest => adPlacement == vipAdPlacement;
  bool get isFeaturedAdRequest => adPlacement == featuredHomeAdPlacement;
  bool get isCategoryTopRequest =>
      effectiveAdPlacement == categoryTopAdPlacement;
  bool get hasCouponDetails => isCoupon || wantsRestaurantCoupon;
  bool get isEvent => selectedCategory == 'فعاليات';

  @override
  void initState() {
    super.initState();
    adPlacement = widget.initialAdPlacement;
    selectedCategory =
        widget.initialCategory ??
        (widget.initialAdPlacement != null ? restaurantCategory : 'وظيفة');
    selectedSubtype = widget.initialSubCategory;
  }

  @override
  void dispose() {
    scrollController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    cityController.dispose();
    addressController.dispose();
    zipController.dispose();
    phoneController.dispose();
    priceController.dispose();
    couponValueController.dispose();
    couponLimitController.dispose();
    couponTermsController.dispose();
    super.dispose();
  }

  Future<void> pickImages() async {
    if (maxImages > 1) {
      final List<XFile> images = await picker.pickMultiImage(imageQuality: 70);
      if (images.isEmpty) return;

      final remaining = maxImages - selectedImages.length;
      final picked = images.take(remaining).map((e) => File(e.path)).toList();

      setState(() => selectedImages.addAll(picked));

      if (images.length > remaining && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'يمكنك إضافة 5 صور كحد أقصى',
                'You can add up to 5 images only',
              ),
            ),
          ),
        );
      }
    } else {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          selectedImages
            ..clear()
            ..add(File(image.path));
        });
      }
    }
  }

  Future<List<String>> uploadImages({
    required String adId,
    required String userId,
  }) async {
    final List<String> urls = [];

    for (var index = 0; index < selectedImages.length; index++) {
      final image = selectedImages[index];
      final fileName = '${DateTime.now().microsecondsSinceEpoch}_$index.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('ads_images')
          .child(userId)
          .child(adId)
          .child(fileName);

      await ref.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }

  Future<void> publishPost() async {
    if (_publishInFlight) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final needsPhone = selectedCategory != 'سؤال' && (allowCall || allowSms);
    final couponNeedsValue =
        hasCouponDetails &&
        (couponType == null || couponValueController.text.trim().isEmpty);
    final couponNeedsAddress =
        hasCouponDetails && addressController.text.trim().isEmpty;

    if (titleController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty ||
        (selectedCategory != 'سؤال' && cityController.text.trim().isEmpty) ||
        (isPaidAdRequest && selectedImages.isEmpty) ||
        couponNeedsValue ||
        couponNeedsAddress ||
        (hasCouponDetails && couponEndDate == null) ||
        (needsPhone && phoneController.text.trim().isEmpty) ||
        (selectedCategory != 'سؤال' &&
            !isPaidAdRequest &&
            !allowCall &&
            !allowSms &&
            !allowInAppMessage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !allowCall && !allowSms && !allowInAppMessage
                ? t(
                    'اختر طريقة تواصل واحدة على الأقل',
                    'Choose at least one contact method',
                  )
                : t(
                    hasCouponDetails
                        ? 'اختر نوع العرض وعبّي معلومات الكوبون والعنوان والمدة'
                        : isPaidAdRequest
                        ? 'عبّي معلومات الإعلان وارفع الصورة المطلوبة'
                        : 'عبّي كل الحقول المطلوبة',
                    hasCouponDetails
                        ? 'Choose offer type and fill coupon details, address, and duration'
                        : isPaidAdRequest
                        ? 'Fill ad details and upload the required image'
                        : 'Please fill all required fields',
                  ),
          ),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'سجّل الدخول أولاً حتى تقدر تنشر إعلان',
              'Please log in before posting an ad',
            ),
          ),
        ),
      );
      return;
    }

    _publishInFlight = true;
    setState(() => isLoading = true);

    try {
      final adRef = FirebaseFirestore.instance.collection('ads').doc();
      final imageUrls = await uploadImages(adId: adRef.id, userId: user.uid);
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final authorName = _safeName(
        userData['name']?.toString(),
        user.displayName ?? user.email,
      );
      final authorPhotoUrl =
          userData['photoUrl']?.toString() ?? user.photoURL ?? '';
      final paidType = _requestedPaidType();
      final placementLabel = _requestedPlacementLabel();
      final isAlwaysFreeCategory = isFreePromotionCategory(selectedCategory);
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(Duration(days: selectedDurationDays)),
      );

      await adRef.set({
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'city': cityController.text.trim(),
        'address': addressController.text.trim(),
        'zipCode': zipController.text.trim(),
        if (hasCouponDetails) ...{
          'hasCoupon': true,
          'merchantName': isCoupon
              ? descriptionController.text.trim()
              : titleController.text.trim(),
        },
        'phone': cleanPhoneInput(phoneController.text),
        'price': cleanMoneyInput(priceController.text),
        'category': selectedCategory,
        if (selectedSubtype != null && selectedSubtype!.isNotEmpty)
          'subCategory': selectedSubtype,
        if (selectedSubtype != null && selectedSubtype!.isNotEmpty)
          'subCategoryLabelAr':
              selectedSubtypeLabelAr ?? subtypeLabel(selectedSubtype!, true),
        if (selectedSubtype != null && selectedSubtype!.isNotEmpty)
          'subCategoryLabelEn':
              selectedSubtypeLabelEn ?? subtypeLabel(selectedSubtype!, false),
        if (!isAlwaysFreeCategory) ...{
          'requestedDurationDays': selectedDurationDays,
          'adDurationDays': selectedDurationDays,
        },
        if (isEvent && eventDate != null)
          'eventDate': Timestamp.fromDate(eventDate!),
        if (isPaidAdRequest && !isAlwaysFreeCategory) ...{
          'adPlacement': effectiveAdPlacement,
          'paidAdType': paidType,
          'isPaidAdRequest': true,
          'requestedCategory': selectedCategory,
          'requestedPlacementLabel': placementLabel,
          'paymentRequired': false,
          'paymentStatus': 'free_pilot',
          'paidLaunchMode': 'free_until_payments_enabled',
        } else ...{
          'paymentRequired': false,
          'paymentStatus': 'not_required',
        },
        if (isHousing) 'housingType': housingType,
        if (hasCouponDetails) ...{
          'couponType': couponType,
          'couponValue': couponType == 'percent'
              ? cleanPercentInput(couponValueController.text)
              : couponType == 'amount'
              ? cleanMoneyInput(couponValueController.text)
              : couponValueController.text.trim(),
          'couponEndsAt': Timestamp.fromDate(couponEndDate!),
          'couponLimit': int.tryParse(couponLimitController.text.trim()) ?? 0,
          'couponTerms': couponTermsController.text.trim(),
          'claimedCount': 0,
          'usedCount': 0,
          'onePerUser': true,
        },
        'allowCall': allowCall,
        'allowSms': allowSms,
        'allowInAppMessage': allowInAppMessage,
        'views': 0,
        'favoritesCount': 0,
        'likesCount': 0,
        'commentsCount': 0,
        'status': widget.publishImmediately ? 'approved' : 'pending',
        'isFeatured': false,
        'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : '',
        'imageUrls': imageUrls,
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        if (widget.createdByAdmin) 'createdByAdmin': true,
        'createdAt': FieldValue.serverTimestamp(),
        if (widget.publishImmediately)
          'approvedAt': FieldValue.serverTimestamp(),
        if (widget.publishImmediately && !isAlwaysFreeCategory)
          'activeUntil': expiresAt,
      });

      if (selectedCategory == 'خدمة' && selectedSubtype == 'other') {
        try {
          await trackOtherServiceCategorySuggestion(
            label: titleController.text,
            adId: adRef.id,
            userId: user.uid,
          );
        } catch (e) {
          debugPrint('Service category suggestion tracking failed: $e');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم إرسال الإعلان للمراجعة', 'Post sent for review')),
        ),
      );

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      debugPrint(
        'AddPost FirebaseException: plugin=${e.plugin}, code=${e.code}, message=${e.message}',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_firebasePublishErrorMessage(e))));
    } catch (e) {
      if (!mounted) return;

      debugPrint('AddPost publish error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('حدث خطأ أثناء النشر', 'Error while publishing')),
        ),
      );
    }

    _publishInFlight = false;
    if (mounted) setState(() => isLoading = false);
  }

  String _firebasePublishErrorMessage(FirebaseException error) {
    if (error.code == 'permission-denied' || error.code == 'unauthorized') {
      return t(
        'ما عندك صلاحية للنشر. سجّل الدخول وجرب مرة ثانية.',
        'You do not have permission to post. Log in and try again.',
      );
    }
    if (error.plugin == 'firebase_storage') {
      return t(
        'تعذر رفع الصورة. جرّب صورة ثانية أو أعد المحاولة.',
        'Could not upload the image. Try another image or retry.',
      );
    }
    if (error.code == 'unavailable' || error.code == 'network-request-failed') {
      return t(
        'تعذر الاتصال بفايربيز. تأكد من الإنترنت وجرب مرة ثانية.',
        'Could not reach Firebase. Check your connection and try again.',
      );
    }
    return t('حدث خطأ أثناء النشر', 'Error while publishing');
  }

  String _requestedPaidType() {
    if (isVipAdRequest) return 'home_vip';
    if (isFeaturedAdRequest) return 'featured';
    if (isCategoryTopRequest) return 'category_top';
    return '';
  }

  String _requestedPlacementLabel() {
    if (isVipAdRequest) {
      return t('إعلان VIP أعلى الصفحة', 'VIP ad at the top of the home page');
    }
    if (isFeaturedAdRequest) {
      return t('إعلان مميز تحت VIP', 'Featured ad below VIP');
    }
    if (isCategoryTopRequest) {
      return t('أولوية أول 10 داخل القسم', 'Top 10 priority inside category');
    }
    return t('إعلان عادي', 'Regular ad');
  }

  Future<void> formatDescriptionWithAi() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (titleController.text.trim().isEmpty &&
        descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'اكتب عنوان أو وصف بسيط أولاً',
              'Write a title or a short note first',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => isFormattingDescription = true);

    try {
      final formatted = await AiDescriptionService.formatDescription(
        title: titleController.text,
        description: descriptionController.text,
        category: selectedCategory,
        isArabic: widget.isArabic,
      );

      if (!mounted) return;
      descriptionController.text = formatted;
      descriptionController.selection = TextSelection.collapsed(
        offset: descriptionController.text.length,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('تمت كتابة الوصف', 'Description generated'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'تعذرت كتابة الوصف حالياً. تأكد من تسجيل الدخول وإعداد الذكاء الاصطناعي.',
              'Could not generate the description now. Check login and AI setup.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isFormattingDescription = false);
    }
  }

  String priceHint() {
    if (isPaidAdRequest) {
      return t(
        'ملاحظات أو مدة الإعلان - اختياري',
        'Notes or ad duration - optional',
      );
    }
    if (selectedCategory == 'وظيفة') {
      return t('الراتب أو الأجر - اختياري', 'Salary or pay - optional');
    }
    if (selectedCategory == 'سكن') {
      if (housingType == 'بيع') {
        return t('السعر - اختياري', 'Price - optional');
      }
      if (housingType == 'شريك سكن') {
        return t('المساهمة الشهرية - اختياري', 'Monthly share - optional');
      }
      return t('الإيجار الشهري - اختياري', 'Monthly rent - optional');
    }
    if (selectedCategory == 'خدمة') {
      return t('السعر - اختياري', 'Price - optional');
    }
    if (selectedCategory == 'كوبون') {
      return t('سعر العرض - اختياري', 'Offer price - optional');
    }
    return t('السعر أو التفاصيل - اختياري', 'Price or details - optional');
  }

  void changeCategory(String value) {
    if (value == 'سؤال') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => community_question.AddQuestionScreen(
            isArabic: widget.isArabic,
            isDark: widget.isDark,
          ),
        ),
      );
      return;
    }

    setState(() {
      selectedCategory = value;
      selectedImages.clear();
      selectedSubtype = null;
      selectedSubtypeLabelAr = null;
      selectedSubtypeLabelEn = null;
      if (isFreePromotionCategory(value)) {
        promoteInCategory = false;
      }
      if (!isEvent) eventDate = null;
      if (!isRestaurantOrStore && !isCoupon) {
        wantsRestaurantCoupon = false;
        couponType = null;
        couponValueController.clear();
        couponLimitController.clear();
        couponTermsController.clear();
        couponEndDate = null;
      }
    });
  }

  void scrollToPostInformation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = postInformationKey.currentContext;
      if (context == null) return;

      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.04,
      );
    });
  }

  String screenTitle() {
    if (isVipAdRequest) {
      return t('طلب إعلان VIP', 'Request VIP Ad');
    }
    if (isFeaturedAdRequest) {
      return t('طلب إعلان مميز', 'Request Featured Ad');
    }
    if (!isCategoryLocked) return t('أضف إعلان', 'Add Post');
    if (selectedCategory == 'وظيفة') return t('أضف وظيفة', 'Add Job');
    if (isHousing) return t('أضف سكن', 'Add Housing');
    if (selectedCategory == 'خدمة') return t('أضف خدمة', 'Add Service');
    if (isCoupon) return t('أضف كوبون', 'Add Coupon');
    if (selectedCategory == restaurantCategory) {
      return t('أضف مطعم أو كافيه', 'Add Restaurant or Cafe');
    }
    if (selectedCategory == storesCategory) {
      return t('أضف محل تجاري', 'Add Store');
    }
    return t('أضف إعلان', 'Add Post');
  }

  String titleHint() {
    if (isPaidAdRequest) return t('عنوان الإعلان', 'Ad title');
    if (selectedCategory == 'وظيفة') return t('عنوان الوظيفة', 'Job title');
    if (isHousing) return t('عنوان الإعلان', 'Ad title');
    if (selectedCategory == restaurantCategory) {
      return t('اسم المطعم أو الكافيه', 'Restaurant or cafe name');
    }
    if (selectedCategory == storesCategory) return t('اسم المحل', 'Store name');
    if (selectedCategory == 'فعاليات') {
      return t('اسم المناسبة', 'Event name');
    }
    if (selectedCategory == 'محامين وهجرة') {
      return t('اسم المحامي أو المكتب', 'Lawyer or office name');
    }
    if (selectedCategory == 'خدمة') {
      return t('نوع الخدمة', 'Service type');
    }
    if (isCoupon) return t('عنوان العرض', 'Offer title');
    return t('العنوان', 'Title');
  }

  String descriptionHint() {
    if (isPaidAdRequest) {
      return t('وصف الإعلان أو نص العرض', 'Ad description or offer text');
    }
    if (isCoupon) return t('اسم المحل', 'Store name');
    return t('الوصف', 'Description');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: widget.isDark ? bgDark : Colors.white,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          centerTitle: true,
          title: Text(
            screenTitle(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SafeBottomScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCategoryLocked) ...[
                _sectionTitle(
                  isPaidAdRequest
                      ? t('اختر قسم الإعلان', 'Choose ad category')
                      : t('نوع الإعلان', 'Post Type'),
                ),
                const SizedBox(height: 12),
                _typeCard(Icons.work, t('وظيفة', 'Job'), 'وظيفة'),
                _typeCard(Icons.home, t('سكن', 'Housing'), 'سكن'),
                _typeCard(Icons.handyman, t('خدمة', 'Service'), 'خدمة'),
                _typeCard(Icons.local_offer, t('كوبون', 'Coupon'), 'كوبون'),
                _typeCard(
                  Icons.forum,
                  t('سؤال للجالية', 'Community Question'),
                  'سؤال',
                ),
                _typeCard(
                  Icons.restaurant,
                  t('مطاعم وكافيهات', 'Restaurants & Cafes'),
                  restaurantCategory,
                ),
                _typeCard(
                  Icons.storefront,
                  t('محلات تجارية', 'Stores'),
                  storesCategory,
                ),
                _typeCard(
                  Icons.event,
                  t('فعاليات ومناسبات', 'Events'),
                  'فعاليات',
                ),
                _typeCard(
                  Icons.gavel,
                  t('محامين وهجرة', 'Lawyers & Immigration'),
                  'محامين وهجرة',
                ),
                const SizedBox(height: 24),
              ],

              KeyedSubtree(
                key: postInformationKey,
                child: _sectionTitle(t('معلومات الإعلان', 'Post Information')),
              ),
              const SizedBox(height: 12),

              if (isPaidAdRequest) _paidAdGuidelines(),
              if (canPromoteInCategory) _categoryPromotionCard(),
              if (!isFreePromotionCategory(selectedCategory))
                _durationSelector(),
              if (isHousing) _housingTypeOptions(),
              if (subtypesForCategory(selectedCategory).isNotEmpty)
                _subtypeSelector(),
              _input(titleHint(), titleController),
              _input(
                descriptionHint(),
                descriptionController,
                lines: isCoupon ? 1 : 4,
              ),
              if (!isCoupon) _aiDescriptionButton(),
              if (selectedCategory != 'سؤال') ...[
                CityPickerField(
                  controller: cityController,
                  isArabic: widget.isArabic,
                  isDark: widget.isDark,
                  hint: t('المدينة', 'City'),
                  margin: const EdgeInsets.only(bottom: 12),
                ),
                _input(
                  t(
                    'أضف العنوان الكامل - اختياري',
                    'Add full address - optional',
                  ),
                  addressController,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  suffixIcon: Icons.add_location_alt,
                  accentColor: yaHalaGold,
                  highlighted: true,
                ),
                _input(
                  t('ZIP Code - اختياري', 'ZIP Code - optional'),
                  zipController,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                ),
              ],
              if (isRestaurantOrStore) _restaurantCouponPrompt(),
              if (isEvent) _eventDatePicker(),
              if (hasCouponDetails) _couponOptions(),
              if (selectedCategory != 'سؤال') _contactOptions(),
              if (selectedCategory != 'سؤال' && (allowCall || allowSms))
                _input(
                  t('رقم الهاتف', 'Phone Number'),
                  phoneController,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  inputFormatters: const [PhoneNumberInputFormatter()],
                ),
              if (!isRestaurantOrStore)
                _input(
                  priceHint(),
                  priceController,
                  keyboardType: isPaidAdRequest
                      ? TextInputType.text
                      : TextInputType.number,
                  prefixText: isPaidAdRequest ? null : '\$ ',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  inputFormatters: isPaidAdRequest
                      ? null
                      : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                ),

              const SizedBox(height: 16),

              _imagesPickerBox(),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yaHalaGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: isLoading ? null : publishPost,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.publish, color: Colors.white),
                  label: Text(
                    isLoading
                        ? t('جاري النشر...', 'Publishing...')
                        : t('نشر الإعلان', 'Publish Post'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  t(
                    'سيتم مراجعة الإعلان قبل ظهوره',
                    'Your post will be reviewed before publishing',
                  ),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: widget.isDark ? Colors.white : Colors.black,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    );
  }

  Widget _paidAdGuidelines() {
    final sizeText = isVipAdRequest
        ? t('المقاس الأفضل: 1200 × 540 بكسل', 'Best size: 1200 x 540 px')
        : isFeaturedAdRequest
        ? t('المقاس الأفضل: 900 × 500 بكسل', 'Best size: 900 x 500 px')
        : t(
            'صورة واحدة واضحة تكفي لتمييز الإعلان داخل القسم',
            'One clear image is enough for category priority',
          );
    final placementText = isVipAdRequest
        ? t(
            'هذا الإعلان يظهر أعلى الصفحة الرئيسية كأقوى مساحة إعلانية.',
            'This ad appears at the top of the home page as the strongest ad spot.',
          )
        : isFeaturedAdRequest
        ? t(
            'هذا الإعلان يظهر ضمن قسم الإعلانات المميزة أسفل إعلان VIP.',
            'This ad appears in the featured ads section below the VIP ad.',
          )
        : t(
            'هذا الإعلان يبقى داخل نفس القسم ويظهر ضمن أول الإعلانات.',
            'This ad stays in this category and appears near the top.',
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: yaHalaGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: yaHalaGold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.workspace_premium, color: yaHalaGold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVipAdRequest
                      ? t('إعلان VIP أعلى الصفحة', 'Top Page VIP Ad')
                      : isFeaturedAdRequest
                      ? t('إعلان مميز', 'Featured Ad')
                      : t('تمييز داخل القسم', 'Category priority'),
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$sizeText\n$placementText',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white70 : Colors.black87,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryPromotionCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: promoteInCategory
            ? yaHalaGreen.withValues(alpha: 0.10)
            : (widget.isDark ? cardColor : const Color(0xFFF3F3F3)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: promoteInCategory
              ? yaHalaGreen.withValues(alpha: 0.45)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: yaHalaGold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.trending_up, color: yaHalaGold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(
                    'اجعل إعلانك مميز داخل القسم',
                    'Promote inside this category',
                  ),
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t(
                    'حاليا مجاني، وبعدين منفعّل الدفع لما يكبر التطبيق.',
                    'Free for now. Payment can be enabled later.',
                  ),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: promoteInCategory,
            activeThumbColor: yaHalaGreen,
            onChanged: isLoading
                ? null
                : (value) {
                    setState(() {
                      promoteInCategory = value;
                      if (value && selectedImages.length > 1) {
                        final firstImage = selectedImages.first;
                        selectedImages
                          ..clear()
                          ..add(firstImage);
                      }
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _durationSelector() {
    String labelFor(int days) {
      if (days == 7) return t('أسبوع', '1 week');
      if (days == 14) return t('أسبوعين', '2 weeks');
      return t('شهر', '1 month');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('مدة الإعلان', 'Ad duration'),
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: adDurationOptionsDays.map((days) {
              final selected = selectedDurationDays == days;
              return ChoiceChip(
                selected: selected,
                label: Text(labelFor(days)),
                selectedColor: yaHalaGreen,
                backgroundColor: widget.isDark ? bgDark : Colors.white,
                labelStyle: TextStyle(
                  color: selected
                      ? Colors.white
                      : (widget.isDark ? Colors.white : Colors.black),
                  fontWeight: FontWeight.w800,
                ),
                onSelected: isLoading
                    ? null
                    : (_) => setState(() => selectedDurationDays = days),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _aiDescriptionButton() {
    return Align(
      alignment: widget.isArabic ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: yaHalaGreen,
            side: const BorderSide(color: yaHalaGreen),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: isFormattingDescription ? null : formatDescriptionWithAi,
          icon: isFormattingDescription
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            isFormattingDescription
                ? t('جاري الكتابة...', 'Writing...')
                : t('اكتب الوصف بالذكاء الاصطناعي', 'Write with AI'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  Widget _imagesPickerBox() {
    return GestureDetector(
      onTap: isLoading ? null : pickImages,
      child: Container(
        width: double.infinity,
        height: selectedImages.isEmpty ? 160 : 190,
        decoration: BoxDecoration(
          color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: selectedImages.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    size: 36,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    maxImages > 1
                        ? t('اختر الصور - حتى 5 صور', 'Choose images - up to 5')
                        : t('اختر صورة للإعلان', 'Choose ad image'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(10),
                      itemCount:
                          selectedImages.length +
                          (selectedImages.length < maxImages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == selectedImages.length) {
                          return Container(
                            width: 110,
                            margin: const EdgeInsetsDirectional.only(end: 10),
                            decoration: BoxDecoration(
                              color: widget.isDark ? bgDark : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: const Icon(
                              Icons.add_photo_alternate,
                              color: Colors.grey,
                            ),
                          );
                        }

                        return Stack(
                          children: [
                            Container(
                              width: 120,
                              margin: const EdgeInsetsDirectional.only(end: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  selectedImages[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            PositionedDirectional(
                              top: 6,
                              end: 16,
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => selectedImages.removeAt(index),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      t(
                        '${selectedImages.length} من $maxImages صور',
                        '${selectedImages.length} of $maxImages images',
                      ),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _contactOptions() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('طرق التواصل', 'Contact methods'),
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _contactSwitch(
            icon: Icons.phone,
            title: t('اتصال', 'Phone call'),
            value: allowCall,
            onChanged: (value) => setState(() => allowCall = value),
          ),
          _contactSwitch(
            icon: Icons.sms,
            title: t('رسالة نصية', 'Text message'),
            value: allowSms,
            onChanged: (value) => setState(() => allowSms = value),
          ),
          _contactSwitch(
            icon: Icons.chat,
            title: t('رسالة عبر يا هلا', 'Message via Ya Hala'),
            value: allowInAppMessage,
            onChanged: (value) => setState(() => allowInAppMessage = value),
          ),
        ],
      ),
    );
  }

  Widget _restaurantCouponPrompt() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: yaHalaGold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_offer, color: yaHalaGold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('بدك تضيف كوبون للمحل؟', 'Add a coupon for this place?'),
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t(
                    'بيظهر الإعلان كمان بقسم الكوبونات',
                    'It will also appear in the coupons section',
                  ),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: wantsRestaurantCoupon,
            activeThumbColor: yaHalaGreen,
            onChanged: isLoading
                ? null
                : (value) {
                    setState(() {
                      wantsRestaurantCoupon = value;
                      if (!value) {
                        couponType = null;
                        couponValueController.clear();
                        couponLimitController.clear();
                        couponTermsController.clear();
                        couponEndDate = null;
                      }
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _couponOptions() {
    final couponTypeOptions = [
      (
        value: 'percent',
        label: t('خصم بالمية', 'Percent off'),
        icon: Icons.percent,
      ),
      (
        value: 'amount',
        label: t('خصم مبلغ', 'Amount off'),
        icon: Icons.attach_money,
      ),
      (
        value: 'buy_get',
        label: t('اشتري واحصل', 'Buy X get Y'),
        icon: Icons.redeem,
      ),
      (
        value: 'special',
        label: t('عرض خاص', 'Special offer'),
        icon: Icons.local_offer,
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('تفاصيل الكوبون', 'Coupon details'),
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t('نوع العرض', 'Offer type'),
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: couponTypeOptions.map((option) {
              final selected = couponType == option.value;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: isLoading
                    ? null
                    : () {
                        setState(() {
                          couponType = option.value;
                          couponValueController.clear();
                        });
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? yaHalaGreen
                        : (widget.isDark ? bgDark : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? yaHalaGreen
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        option.icon,
                        size: 17,
                        color: selected ? Colors.white : yaHalaGold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        option.label,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : (widget.isDark ? Colors.white : Colors.black),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (couponType != null) ...[
            const SizedBox(height: 12),
            _couponInput(
              icon: _couponValueIcon(),
              hint: _couponValueHint(),
              controller: couponValueController,
              keyboardType: couponType == 'percent' || couponType == 'amount'
                  ? TextInputType.number
                  : TextInputType.text,
              suffixText: couponType == 'percent'
                  ? '%'
                  : couponType == 'amount'
                  ? '\$'
                  : null,
              inputFormatters: couponType == 'percent' || couponType == 'amount'
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
                  : null,
            ),
          ],
          _couponInput(
            icon: Icons.confirmation_number_outlined,
            hint: t(
              'عدد الكوبونات - اتركه فاضي لغير محدود',
              'Coupon quantity - empty for unlimited',
            ),
            controller: couponLimitController,
            keyboardType: TextInputType.number,
          ),
          _couponInput(
            icon: Icons.rule,
            hint: t('شروط العرض - اختياري', 'Offer terms - optional'),
            controller: couponTermsController,
            lines: 2,
          ),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isLoading ? null : _pickCouponEndDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.isDark ? bgDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, color: yaHalaGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      couponEndDate == null
                          ? t(
                              'اختر تاريخ انتهاء العرض',
                              'Choose offer end date',
                            )
                          : t(
                              'ينتهي في ${_formatDate(couponEndDate!)}',
                              'Ends on ${_formatDate(couponEndDate!)}',
                            ),
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _couponValueHint() {
    if (couponType == 'percent') {
      return t('نسبة الخصم مثل 20', 'Discount percent, e.g. 20');
    }
    if (couponType == 'amount') {
      return t('قيمة الخصم مثل 10 دولار', 'Discount amount, e.g. 10 dollars');
    }
    if (couponType == 'buy_get') {
      return t(
        'مثال: اشتري وجبة واحصل على مشروب',
        'Example: buy a meal, get a drink',
      );
    }
    return t('نص العرض', 'Offer text');
  }

  IconData _couponValueIcon() {
    if (couponType == 'percent') return Icons.percent;
    if (couponType == 'amount') return Icons.attach_money;
    if (couponType == 'buy_get') return Icons.redeem;
    return Icons.local_offer;
  }

  Widget _couponInput({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    int lines = 1,
    TextInputType? keyboardType,
    String? suffixText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? bgDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFE2E2E2),
        ),
        boxShadow: widget.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: TextField(
        controller: controller,
        maxLines: lines,
        keyboardType: keyboardType ?? TextInputType.text,
        inputFormatters: inputFormatters,
        style: TextStyle(
          color: widget.isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: yaHalaGreen),
          suffixText: suffixText,
          suffixStyle: const TextStyle(
            color: yaHalaGold,
            fontWeight: FontWeight.w900,
          ),
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF8D8D8D),
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Future<void> _pickCouponEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: couponEndDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => couponEndDate = picked);
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: eventDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() => eventDate = picked);
  }

  Widget _eventDatePicker() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isLoading ? null : _pickEventDate,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.event, color: yaHalaGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                eventDate == null
                    ? t('تاريخ الفعالية - اختياري', 'Event date - optional')
                    : t(
                        'تاريخ الفعالية: ${_formatDate(eventDate!)}',
                        'Event date: ${_formatDate(eventDate!)}',
                      ),
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (eventDate != null)
              IconButton(
                onPressed: isLoading
                    ? null
                    : () => setState(() => eventDate = null),
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _contactSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        value: value,
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeThumbColor: yaHalaGreen,
        secondary: Icon(icon, color: value ? yaHalaGreen : Colors.grey),
        title: Text(
          title,
          style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
        ),
        onChanged: isLoading ? null : onChanged,
      ),
    );
  }

  Widget _housingTypeOptions() {
    final options = [
      (value: 'بيع', label: t('بيع', 'Sale'), icon: Icons.sell),
      (value: 'إيجار', label: t('إيجار', 'Rent'), icon: Icons.home_work),
      (value: 'شريك سكن', label: t('شريك سكن', 'Roommate'), icon: Icons.group),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('نوع السكن', 'Housing type'),
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final selected = housingType == option.value;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: isLoading
                    ? null
                    : () => setState(() => housingType = option.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? yaHalaGreen
                        : (widget.isDark ? bgDark : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? yaHalaGreen
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        option.icon,
                        size: 18,
                        color: selected ? Colors.white : yaHalaGreen,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        option.label,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : (widget.isDark ? Colors.white : Colors.black),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _typeCard(IconData icon, String title, String value) {
    final selected = selectedCategory == value;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        changeCategory(value);
        if (!isCategoryLocked) scrollToPostInformation();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFF7E6)
              : (widget.isDark ? cardColor : const Color(0xFFF3F3F3)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? yaHalaGold
                : (widget.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08)),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? yaHalaGold : yaHalaGreen),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: selected
                    ? Colors.black
                    : (widget.isDark ? Colors.white : Colors.black),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (selected) const Icon(Icons.check_circle, color: yaHalaGold),
          ],
        ),
      ),
    );
  }

  Widget _subtypeSelector() {
    final options = subtypesForCategory(selectedCategory);
    if (options.isEmpty) return const SizedBox.shrink();

    if (selectedCategory == 'خدمة') {
      return StreamBuilder<List<CategorySubtypeOption>>(
        stream: approvedServiceCategoriesStream(widget.isArabic),
        builder: (context, snapshot) {
          return _subtypeDropdown([...options, ...?snapshot.data]);
        },
      );
    }

    return _subtypeDropdown(options);
  }

  Widget _subtypeDropdown(List<CategorySubtypeOption> options) {
    final selectedValue =
        options.any((option) => option.value == selectedSubtype)
        ? selectedSubtype
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: yaHalaGreen),
          dropdownColor: widget.isDark ? cardColor : Colors.white,
          hint: Text(
            _subtypeHint(),
            style: const TextStyle(color: Colors.grey),
          ),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option.value,
                  child: Text(
                    widget.isArabic ? option.ar : option.en,
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: isLoading
              ? null
              : (value) {
                  setState(() {
                    selectedSubtype = value;
                    final selectedOption = options.where(
                      (option) => option.value == value,
                    );
                    if (selectedOption.isEmpty) {
                      selectedSubtypeLabelAr = null;
                      selectedSubtypeLabelEn = null;
                    } else {
                      selectedSubtypeLabelAr = selectedOption.first.ar;
                      selectedSubtypeLabelEn = selectedOption.first.en;
                    }
                    if (!hasSelectedSubtype) promoteInCategory = false;
                  });
                },
        ),
      ),
    );
  }

  String _subtypeHint() {
    if (selectedCategory == 'خدمة') {
      return t('اختر نوع الخدمة', 'Choose service type');
    }
    if (selectedCategory == restaurantCategory) {
      return t('اختر نوع المطعم', 'Choose restaurant type');
    }
    if (selectedCategory == storesCategory) {
      return t('اختر نوع المحل', 'Choose store type');
    }
    if (selectedCategory == 'محامين وهجرة') {
      return t('اختر نوع الخدمة القانونية', 'Choose legal service type');
    }
    return t('اختر النوع', 'Choose type');
  }

  Widget _input(
    String hint,
    TextEditingController controller, {
    int lines = 1,
    TextInputType? keyboardType,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
    TextDirection? textDirection,
    TextAlign? textAlign,
    IconData? suffixIcon,
    Color? accentColor,
    bool highlighted = false,
  }) {
    final activeAccent = accentColor ?? yaHalaGold;
    final radius = BorderRadius.circular(16);
    final enabledBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: highlighted
            ? activeAccent.withValues(alpha: widget.isDark ? 0.85 : 0.58)
            : Colors.transparent,
        width: highlighted ? 1.6 : 0,
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: lines,
        inputFormatters: inputFormatters,
        textDirection: textDirection,
        textAlign: textAlign ?? TextAlign.start,
        style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
        keyboardType:
            keyboardType ??
            (hint.contains('الهاتف') ||
                    hint.contains('Phone') ||
                    hint.contains('ZIP')
                ? TextInputType.phone
                : TextInputType.text),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefixText,
          prefixStyle: const TextStyle(
            color: yaHalaGold,
            fontWeight: FontWeight.w900,
          ),
          suffixIcon: suffixIcon == null
              ? null
              : Icon(suffixIcon, color: activeAccent),
          hintStyle: TextStyle(
            color: highlighted
                ? activeAccent.withValues(alpha: widget.isDark ? 0.95 : 0.85)
                : Colors.grey,
            fontWeight: highlighted ? FontWeight.w800 : FontWeight.normal,
          ),
          filled: true,
          fillColor: highlighted
              ? activeAccent.withValues(alpha: widget.isDark ? 0.12 : 0.08)
              : widget.isDark
              ? cardColor
              : const Color(0xFFF3F3F3),
          border: enabledBorder,
          enabledBorder: enabledBorder,
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(
              color: highlighted ? activeAccent : yaHalaGreen,
              width: highlighted ? 2 : 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

String _safeName(String? primary, String? fallback) {
  final first = primary?.trim() ?? '';
  if (first.isNotEmpty && !first.contains('@')) return first;

  final second = fallback?.trim() ?? '';
  if (second.isNotEmpty && !second.contains('@')) return second;

  return 'مستخدم يا هلا';
}
