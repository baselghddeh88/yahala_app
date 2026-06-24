import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../services/ai_description_service.dart';
import '../utils/ad_promotion.dart';
import '../utils/category_subtypes.dart';
import '../utils/value_formatters.dart';
import '../widgets/city_picker_field.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class EditAdScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;
  final String docId;
  final Map<String, dynamic> data;

  const EditAdScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    required this.docId,
    required this.data,
  });

  @override
  State<EditAdScreen> createState() => _EditAdScreenState();
}

class _EditAdScreenState extends State<EditAdScreen> {
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
  final ImagePicker picker = ImagePicker();
  final List<File> selectedImages = [];
  late List<String> existingImageUrls;
  bool allowCall = true;
  bool allowSms = true;
  bool allowInAppMessage = true;
  bool promoteInCategory = false;
  bool wantsRestaurantCoupon = false;
  String housingType = 'إيجار';
  String? selectedSubtype;
  String? couponType;
  int selectedDurationDays = 30;
  DateTime? couponEndDate;
  DateTime? eventDate;

  bool isSaving = false;
  bool _saveInFlight = false;
  bool isFormattingDescription = false;
  String get category => widget.data['category']?.toString() ?? '';
  bool get isHousing => category == 'سكن';
  bool get isRestaurantOrStore => isRestaurantOrStoreCategory(category);
  bool get isCoupon => category == 'كوبون';
  bool get isQuestion => category == 'سؤال';
  bool get isEvent => category == 'فعاليات';
  bool get isPaidAdRequest =>
      (widget.data['adPlacement']?.toString() ?? '').isNotEmpty ||
      promoteInCategory;
  bool get isVipAdRequest => widget.data['adPlacement'] == vipAdPlacement;
  bool get isFeaturedHomeRequest =>
      widget.data['adPlacement'] == featuredHomeAdPlacement;
  bool get isHomePaidAdRequest => isVipAdRequest || isFeaturedHomeRequest;
  bool get hasCouponDetails => isCoupon || wantsRestaurantCoupon;
  bool get hasSubtypeOptions => subtypesForCategory(category).isNotEmpty;
  bool get hasSelectedSubtype =>
      selectedSubtype != null && selectedSubtype!.isNotEmpty;
  bool get canPromoteInCategory =>
      !isFreePromotionCategory(category) &&
      !isHomePaidAdRequest &&
      (!hasSubtypeOptions || hasSelectedSubtype);

  int get maxImages {
    return category == 'سكن' ? 5 : 1;
  }

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();

    titleController.text = widget.data['title']?.toString() ?? '';
    descriptionController.text = widget.data['description']?.toString() ?? '';
    cityController.text = widget.data['city']?.toString() ?? '';
    addressController.text = widget.data['address']?.toString() ?? '';
    zipController.text = widget.data['zipCode']?.toString() ?? '';
    phoneController.text = formatPhoneNumber(
      widget.data['phone']?.toString() ?? '',
    );
    priceController.text = widget.data['price']?.toString() ?? '';
    housingType = widget.data['housingType']?.toString() ?? housingType;
    selectedSubtype = widget.data['subCategory']?.toString();
    promoteInCategory =
        widget.data['adPlacement']?.toString() == categoryTopAdPlacement ||
        widget.data['paidAdType']?.toString() == 'category_top';
    final duration =
        widget.data['requestedDurationDays'] ?? widget.data['adDurationDays'];
    if (duration is int && adDurationOptionsDays.contains(duration)) {
      selectedDurationDays = duration;
    } else if (duration is num &&
        adDurationOptionsDays.contains(duration.toInt())) {
      selectedDurationDays = duration.toInt();
    }
    wantsRestaurantCoupon =
        isRestaurantOrStore && widget.data['hasCoupon'] == true;
    couponType = widget.data['couponType']?.toString();
    couponValueController.text = widget.data['couponValue']?.toString() ?? '';
    final couponLimit = widget.data['couponLimit'];
    couponLimitController.text = couponLimit == null || couponLimit == 0
        ? ''
        : couponLimit.toString();
    couponTermsController.text = widget.data['couponTerms']?.toString() ?? '';
    final rawCouponEndDate = widget.data['couponEndsAt'];
    if (rawCouponEndDate is Timestamp) {
      couponEndDate = rawCouponEndDate.toDate();
    }
    final rawEventDate = widget.data['eventDate'];
    if (rawEventDate is Timestamp) {
      eventDate = rawEventDate.toDate();
    }
    final hasContactOptions =
        widget.data.containsKey('allowCall') ||
        widget.data.containsKey('allowSms') ||
        widget.data.containsKey('allowInAppMessage');
    allowCall = hasContactOptions ? widget.data['allowCall'] == true : true;
    allowSms = hasContactOptions ? widget.data['allowSms'] == true : true;
    allowInAppMessage = hasContactOptions
        ? widget.data['allowInAppMessage'] == true
        : true;
    existingImageUrls = List<String>.from(widget.data['imageUrls'] ?? []);
    final imageUrl = widget.data['imageUrl']?.toString() ?? '';
    if (existingImageUrls.isEmpty && imageUrl.isNotEmpty) {
      existingImageUrls = [imageUrl];
    }
  }

  @override
  void dispose() {
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

  Future<void> saveAd() async {
    if (_saveInFlight) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final needsPhone = allowCall || allowSms;
    final couponNeedsValue =
        hasCouponDetails &&
        (couponType == null || couponValueController.text.trim().isEmpty);
    final couponNeedsAddress =
        hasCouponDetails && addressController.text.trim().isEmpty;

    if (titleController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty ||
        (!isQuestion && cityController.text.trim().isEmpty) ||
        couponNeedsValue ||
        couponNeedsAddress ||
        (hasCouponDetails && couponEndDate == null) ||
        (needsPhone && phoneController.text.trim().isEmpty) ||
        (!allowCall && !allowSms && !allowInAppMessage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !allowCall && !allowSms && !allowInAppMessage
                ? t(
                    'اختر طريقة تواصل واحدة على الأقل',
                    'Choose at least one contact method',
                  )
                : needsPhone && phoneController.text.trim().isEmpty
                ? t('اكتب رقم الهاتف', 'Add a phone number')
                : hasCouponDetails
                ? t(
                    'اختر نوع العرض وعبّي معلومات الكوبون والعنوان والمدة',
                    'Choose offer type and fill coupon details, address, and duration',
                  )
                : t('عبّي الحقول المطلوبة', 'Fill required fields'),
          ),
        ),
      );
      return;
    }

    _saveInFlight = true;
    setState(() => isSaving = true);

    try {
      final uploadedImages = await uploadNewImages();
      final allImages = [...existingImageUrls, ...uploadedImages];
      final requestCategoryPromotion =
          canPromoteInCategory && promoteInCategory;
      final clearCategoryPromotion =
          canPromoteInCategory &&
          !promoteInCategory &&
          widget.data['adPlacement']?.toString() == categoryTopAdPlacement;

      final updateData = <String, dynamic>{
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'city': cityController.text.trim(),
        'address': addressController.text.trim(),
        'zipCode': zipController.text.trim(),
        'phone': cleanPhoneInput(phoneController.text),
        'price': cleanMoneyInput(priceController.text),
        if (isEvent && eventDate != null)
          'eventDate': Timestamp.fromDate(eventDate!)
        else
          'eventDate': FieldValue.delete(),
        if (isHousing) 'housingType': housingType,
        if (hasCouponDetails) ...{
          'hasCoupon': true,
          'merchantName': isCoupon
              ? descriptionController.text.trim()
              : titleController.text.trim(),
          'couponType': couponType,
          'couponValue': couponType == 'percent'
              ? cleanPercentInput(couponValueController.text)
              : couponType == 'amount'
              ? cleanMoneyInput(couponValueController.text)
              : couponValueController.text.trim(),
          'couponEndsAt': Timestamp.fromDate(couponEndDate!),
          'couponLimit': int.tryParse(couponLimitController.text.trim()) ?? 0,
          'couponTerms': couponTermsController.text.trim(),
          'onePerUser': true,
        } else ...{
          'hasCoupon': false,
          'couponType': FieldValue.delete(),
          'couponValue': FieldValue.delete(),
          'couponEndsAt': FieldValue.delete(),
          'couponLimit': FieldValue.delete(),
          'couponTerms': FieldValue.delete(),
        },
        'allowCall': allowCall,
        'allowSms': allowSms,
        'allowInAppMessage': allowInAppMessage,
        'imageUrl': allImages.isNotEmpty ? allImages.first : '',
        'imageUrls': allImages,
        'status': 'pending',
        if (!isFreePromotionCategory(category)) ...{
          'requestedDurationDays': selectedDurationDays,
          'adDurationDays': selectedDurationDays,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (requestCategoryPromotion) {
        updateData.addAll({
          'adPlacement': categoryTopAdPlacement,
          'paidAdType': 'category_top',
          'isPaidAdRequest': true,
          'requestedCategory': category,
          'requestedPlacementLabel': t(
            'أولوية أول 10 داخل القسم',
            'Top 10 priority inside category',
          ),
          'paymentRequired': false,
          'paymentStatus': 'free_pilot',
          'paidLaunchMode': 'free_until_payments_enabled',
        });
      } else if (clearCategoryPromotion) {
        updateData.addAll({
          'adPlacement': FieldValue.delete(),
          'paidAdType': FieldValue.delete(),
          'isPaidAdRequest': FieldValue.delete(),
          'requestedPlacementLabel': FieldValue.delete(),
          'paymentStatus': 'not_required',
          'paidLaunchMode': FieldValue.delete(),
        });
      }

      if (hasSubtypeOptions && hasSelectedSubtype) {
        updateData['subCategory'] = selectedSubtype;
        updateData['subCategoryLabelAr'] = subtypeLabel(selectedSubtype!, true);
        updateData['subCategoryLabelEn'] = subtypeLabel(
          selectedSubtype!,
          false,
        );
      } else if (hasSubtypeOptions) {
        updateData['subCategory'] = FieldValue.delete();
        updateData['subCategoryLabelAr'] = FieldValue.delete();
        updateData['subCategoryLabelEn'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('ads')
          .doc(widget.docId)
          .update(updateData);

      if (!mounted) return;

      setState(() => isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'تم تعديل الإعلان وإرساله للمراجعة',
              'Ad updated and sent for review',
            ),
          ),
        ),
      );

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      debugPrint(
        'EditAd FirebaseException: plugin=${e.plugin}, code=${e.code}, message=${e.message}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_firebaseSaveErrorMessage(e))));
    } catch (e) {
      debugPrint('EditAd save error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('حدث خطأ أثناء الحفظ', 'Error while saving'))),
      );
    } finally {
      _saveInFlight = false;
      if (mounted) setState(() => isSaving = false);
    }
  }

  String _firebaseSaveErrorMessage(FirebaseException error) {
    if (error.code == 'permission-denied' || error.code == 'unauthorized') {
      return t(
        'ما عندك صلاحية لتعديل هذا الإعلان',
        'You do not have permission to edit this ad',
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
    return t('حدث خطأ أثناء الحفظ', 'Error while saving');
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
        category: category,
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

  Future<void> pickImages() async {
    final remaining =
        maxImages - existingImageUrls.length - selectedImages.length;

    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('وصلت للحد الأقصى من الصور', 'Maximum images reached'),
          ),
        ),
      );
      return;
    }

    if (maxImages > 1) {
      final images = await picker.pickMultiImage(imageQuality: 70);
      if (images.isEmpty) return;

      setState(() {
        selectedImages.addAll(
          images.take(remaining).map((image) => File(image.path)),
        );
      });
      return;
    }

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() {
      existingImageUrls.clear();
      selectedImages
        ..clear()
        ..add(File(image.path));
    });
  }

  Future<List<String>> uploadNewImages() async {
    final urls = <String>[];
    final ownerId = widget.data['userId']?.toString().trim();

    for (var index = 0; index < selectedImages.length; index++) {
      final image = selectedImages[index];
      final fileName = '${DateTime.now().microsecondsSinceEpoch}_$index.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('ads_images')
          .child(ownerId == null || ownerId.isEmpty ? 'unknown' : ownerId)
          .child(widget.docId)
          .child(fileName);

      await ref.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: widget.isDark ? bgDark : Colors.white,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          centerTitle: true,
          title: Text(
            t('تعديل الإعلان', 'Edit Ad'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(t('صور الإعلان', 'Ad Photos')),
              const SizedBox(height: 12),
              _imageEditor(),
              const SizedBox(height: 18),
              _sectionTitle(t('معلومات الإعلان', 'Ad Information')),
              const SizedBox(height: 12),
              if (isPaidAdRequest) _paidAdGuidelines(),
              if (isHousing) _housingTypeOptions(),
              if (hasSubtypeOptions) _subtypeSelector(),
              if (canPromoteInCategory) _categoryPromotionCard(),
              if (isPaidAdRequest || canPromoteInCategory) _durationSelector(),
              _input(
                controller: titleController,
                hint: titleHint(),
                icon: Icons.title,
              ),
              const SizedBox(height: 14),
              _input(
                controller: descriptionController,
                hint: descriptionHint(),
                icon: Icons.description,
                maxLines: isCoupon ? 1 : 4,
              ),
              if (!isCoupon) _aiDescriptionButton(),
              if (!isQuestion) ...[
                const SizedBox(height: 14),
                CityPickerField(
                  controller: cityController,
                  isArabic: widget.isArabic,
                  isDark: widget.isDark,
                  hint: t('المدينة', 'City'),
                ),
                const SizedBox(height: 14),
                _input(
                  controller: addressController,
                  hint: t(
                    'العنوان الكامل - اختياري',
                    'Full address - optional',
                  ),
                  icon: Icons.location_on,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 14),
                _input(
                  controller: zipController,
                  hint: t('ZIP Code - اختياري', 'ZIP Code - optional'),
                  icon: Icons.pin_drop,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                ),
              ],
              const SizedBox(height: 14),
              if (isRestaurantOrStore) _restaurantCouponPrompt(),
              if (isEvent) _eventDatePicker(),
              if (hasCouponDetails) _couponOptions(),
              if (!isQuestion) _contactOptions(),
              if (!isQuestion && (allowCall || allowSms)) ...[
                _input(
                  controller: phoneController,
                  hint: t('رقم الهاتف', 'Phone Number'),
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: const [PhoneNumberInputFormatter()],
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 14),
              ],
              if (!isRestaurantOrStore)
                _input(
                  controller: priceController,
                  hint: priceHint(),
                  icon: Icons.attach_money,
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yaHalaGold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: isSaving ? null : saveAd,
                  child: isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          t('حفظ التعديل', 'Save Changes'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
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
        fontWeight: FontWeight.w900,
        fontSize: 18,
      ),
    );
  }

  String titleHint() {
    if (isPaidAdRequest) return t('عنوان الإعلان', 'Ad title');
    if (category == 'وظيفة') return t('عنوان الوظيفة', 'Job title');
    if (isHousing) return t('عنوان الإعلان', 'Ad title');
    if (category == restaurantCategory ||
        category == legacyRestaurantStoreCategory) {
      return t('اسم المطعم أو الكافيه', 'Restaurant or cafe name');
    }
    if (category == storesCategory) return t('اسم المحل', 'Store name');
    if (category == 'فعاليات') return t('اسم المناسبة', 'Event name');
    if (category == 'محامين وهجرة') {
      return t('اسم المحامي أو المكتب', 'Lawyer or office name');
    }
    if (category == 'خدمة') return t('نوع الخدمة', 'Service type');
    if (isCoupon) return t('عنوان العرض', 'Offer title');
    if (isQuestion) return t('السؤال', 'Question');
    return t('العنوان', 'Title');
  }

  String descriptionHint() {
    if (isPaidAdRequest) {
      return t('وصف الإعلان أو نص العرض', 'Ad description or offer text');
    }
    if (isCoupon) return t('اسم المحل', 'Store name');
    return t('الوصف', 'Description');
  }

  String priceHint() {
    if (isPaidAdRequest) {
      return t(
        'ملاحظات أو مدة الإعلان - اختياري',
        'Notes or ad duration - optional',
      );
    }
    if (category == 'وظيفة') {
      return t('الراتب أو الأجر - اختياري', 'Salary or pay - optional');
    }
    if (isHousing) {
      if (housingType == 'بيع') return t('السعر - اختياري', 'Price - optional');
      if (housingType == 'شريك سكن') {
        return t('المساهمة الشهرية - اختياري', 'Monthly share - optional');
      }
      return t('الإيجار الشهري - اختياري', 'Monthly rent - optional');
    }
    if (category == 'خدمة') return t('السعر - اختياري', 'Price - optional');
    if (isCoupon) return t('سعر العرض - اختياري', 'Offer price - optional');
    return t('السعر أو التفاصيل - اختياري', 'Price or details - optional');
  }

  Widget _paidAdGuidelines() {
    final sizeText = isVipAdRequest
        ? t('المقاس الأفضل: 1200 × 540 بكسل', 'Best size: 1200 x 540 px')
        : isFeaturedHomeRequest
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
        : isFeaturedHomeRequest
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
            child: Text(
              '$placementText\n$sizeText',
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w700,
              ),
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
            onChanged: isSaving
                ? null
                : (value) => setState(() => promoteInCategory = value),
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
                onSelected: isSaving
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
        padding: const EdgeInsets.only(top: 10),
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

  Widget _imageEditor() {
    final currentCount = existingImageUrls.length + selectedImages.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library, color: yaHalaGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('صور الإعلان', 'Ad photos'),
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$currentCount/$maxImages',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...existingImageUrls.map(
                (url) => _imageTile(
                  image: NetworkImage(url),
                  onRemove: () {
                    setState(() => existingImageUrls.remove(url));
                  },
                ),
              ),
              ...selectedImages.map(
                (file) => _imageTile(
                  image: FileImage(file),
                  onRemove: () {
                    setState(() => selectedImages.remove(file));
                  },
                ),
              ),
              if (currentCount < maxImages)
                InkWell(
                  onTap: isSaving ? null : pickImages,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: widget.isDark ? bgDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: yaHalaGold),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate,
                      color: yaHalaGold,
                      size: 34,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageTile({
    required ImageProvider image,
    required VoidCallback onRemove,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(image: image, fit: BoxFit.cover),
          ),
        ),
        PositionedDirectional(
          top: -8,
          end: -8,
          child: InkWell(
            onTap: isSaving ? null : onRemove,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contactOptions() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('طرق التواصل', 'Contact methods'),
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w900,
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
            title: t('رسالة SMS', 'SMS message'),
            value: allowSms,
            onChanged: (value) => setState(() => allowSms = value),
          ),
          _contactSwitch(
            icon: Icons.chat,
            title: t('عن طريق التطبيق', 'Through the app'),
            value: allowInAppMessage,
            onChanged: (value) => setState(() => allowInAppMessage = value),
          ),
        ],
      ),
    );
  }

  Widget _restaurantCouponPrompt() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(18),
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
            onChanged: isSaving
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('تفاصيل الكوبون', 'Coupon details'),
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w900,
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
                onTap: isSaving
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
            onTap: isSaving ? null : _pickCouponEndDate,
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
          fillColor: widget.isDark ? bgDark : Colors.white,
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
      borderRadius: BorderRadius.circular(18),
      onTap: isSaving ? null : _pickEventDate,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(18),
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
                onPressed: isSaving
                    ? null
                    : () => setState(() => eventDate = null),
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
          ],
        ),
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('نوع السكن', 'Housing type'),
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w900,
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
                onTap: isSaving
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
        onChanged: isSaving ? null : onChanged,
      ),
    );
  }

  Widget _subtypeSelector() {
    final options = subtypesForCategory(category);
    if (options.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: hasSelectedSubtype ? selectedSubtype : null,
        isExpanded: true,
        decoration: InputDecoration(
          filled: true,
          fillColor: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
          prefixIcon: const Icon(Icons.category, color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
        dropdownColor: widget.isDark ? cardColor : Colors.white,
        hint: Text(
          t('اختر القسم الفرعي', 'Choose subcategory'),
          style: const TextStyle(color: Colors.grey),
        ),
        style: TextStyle(
          color: widget.isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w800,
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.value,
                child: Text(t(option.ar, option.en)),
              ),
            )
            .toList(),
        onChanged: isSaving
            ? null
            : (value) {
                setState(() => selectedSubtype = value);
              },
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
    TextDirection? textDirection,
    TextAlign? textAlign,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textDirection: textDirection,
      textAlign: textAlign ?? TextAlign.start,
      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          color: yaHalaGold,
          fontWeight: FontWeight.w900,
        ),
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
