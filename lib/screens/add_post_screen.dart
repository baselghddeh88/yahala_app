import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../utils/value_formatters.dart';
import '../widgets/city_picker_field.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class AddPostScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;
  final String? initialCategory;
  final String? initialAdPlacement;

  const AddPostScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    this.initialCategory,
    this.initialAdPlacement,
  });

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  late String selectedCategory;
  bool isLoading = false;

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
  bool allowInAppMessage = false;
  String housingType = 'إيجار';
  String? couponType;
  String? adPlacement;
  DateTime? couponEndDate;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  int get maxImages =>
      selectedCategory == 'سكن' || selectedCategory == 'مطاعم ومحلات' ? 5 : 1;
  bool get isCategoryLocked => widget.initialCategory != null;
  bool get isHousing => selectedCategory == 'سكن';
  bool get isRestaurantOrStore => selectedCategory == 'مطاعم ومحلات';
  bool get isCoupon => selectedCategory == 'كوبون';
  bool get isPaidAdRequest => adPlacement != null;
  bool get isVipAdRequest => adPlacement == 'vip_slider';
  bool get isFeaturedAdRequest => adPlacement == 'featured';

  @override
  void initState() {
    super.initState();
    adPlacement = widget.initialAdPlacement;
    selectedCategory =
        widget.initialCategory ?? (isPaidAdRequest ? 'إعلان مدفوع' : 'وظيفة');
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

  Future<List<String>> uploadImages() async {
    final List<String> urls = [];

    for (final image in selectedImages) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('ads_images')
          .child(fileName);

      await ref.putFile(image);
      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }

  Future<void> publishPost() async {
    final needsPhone = selectedCategory != 'سؤال' && (allowCall || allowSms);
    final couponNeedsValue =
        isCoupon &&
        (couponType == null || couponValueController.text.trim().isEmpty);

    if (titleController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty ||
        (selectedCategory != 'سؤال' && cityController.text.trim().isEmpty) ||
        (selectedCategory != 'سؤال' && addressController.text.trim().isEmpty) ||
        (isPaidAdRequest && selectedImages.isEmpty) ||
        couponNeedsValue ||
        (isCoupon && couponEndDate == null) ||
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
                    isCoupon
                        ? 'اختر نوع العرض وعبّي معلومات الكوبون والمدة'
                        : isPaidAdRequest
                        ? 'عبّي معلومات الإعلان وارفع الصورة المطلوبة'
                        : 'عبّي كل الحقول المطلوبة',
                    isCoupon
                        ? 'Choose offer type and fill coupon details'
                        : isPaidAdRequest
                        ? 'Fill ad details and upload the required image'
                        : 'Please fill all required fields',
                  ),
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final imageUrls = await uploadImages();
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = user == null
          ? null
          : await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
      final userData = userDoc?.data() ?? {};
      final authorName = _safeName(
        userData['name']?.toString(),
        user?.displayName ?? user?.email,
      );
      final authorPhotoUrl =
          userData['photoUrl']?.toString() ?? user?.photoURL ?? '';

      await FirebaseFirestore.instance.collection('ads').add({
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'city': cityController.text.trim(),
        'address': addressController.text.trim(),
        'zipCode': zipController.text.trim(),
        if (isCoupon) ...{'merchantName': descriptionController.text.trim()},
        'phone': phoneController.text.trim(),
        'price': cleanMoneyInput(priceController.text),
        'category': selectedCategory,
        if (isPaidAdRequest) ...{
          'adPlacement': adPlacement,
          'paidAdType': isVipAdRequest ? 'vip' : 'featured',
          'isPaidAdRequest': true,
          'requestedCategory': selectedCategory,
          'requestedPlacementLabel': isVipAdRequest
              ? 'إعلان VIP أعلى الصفحة'
              : 'إعلان مميز',
        },
        if (isHousing) 'housingType': housingType,
        if (isCoupon) ...{
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
        'likesCount': 0,
        'commentsCount': 0,
        'status': 'pending',
        'isFeatured': false,
        'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : '',
        'imageUrls': imageUrls,
        'userId': user?.uid ?? '',
        'userEmail': user?.email ?? '',
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم إرسال الإعلان للمراجعة', 'Post sent for review')),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('حدث خطأ أثناء النشر', 'Error while publishing')),
        ),
      );
    }

    if (mounted) setState(() => isLoading = false);
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
    if (selectedCategory == 'فعاليات') {
      return t('التاريخ أو السعر - اختياري', 'Date or price - optional');
    }
    return t('السعر أو التفاصيل - اختياري', 'Price or details - optional');
  }

  void changeCategory(String value) {
    setState(() {
      selectedCategory = value;
      selectedImages.clear();
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
    if (isRestaurantOrStore) {
      return t('أضف مطعم أو محل', 'Add Restaurant or Store');
    }
    return t('أضف إعلان', 'Add Post');
  }

  String titleHint() {
    if (isPaidAdRequest) return t('عنوان الإعلان', 'Ad title');
    if (selectedCategory == 'وظيفة') return t('عنوان الوظيفة', 'Job title');
    if (isHousing) return t('عنوان الإعلان', 'Ad title');
    if (isRestaurantOrStore) return t('اسم المحل', 'Store name');
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCategoryLocked) ...[
                _sectionTitle(t('نوع الإعلان', 'Post Type')),
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
                  t('مطاعم ومحلات عربية', 'Arab Restaurants & Stores'),
                  'مطاعم ومحلات',
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

              _sectionTitle(t('معلومات الإعلان', 'Post Information')),
              const SizedBox(height: 12),

              if (isPaidAdRequest) _paidAdGuidelines(),
              if (isHousing) _housingTypeOptions(),
              _input(titleHint(), titleController),
              _input(
                descriptionHint(),
                descriptionController,
                lines: isCoupon ? 1 : 4,
              ),
              if (selectedCategory != 'سؤال') ...[
                CityPickerField(
                  controller: cityController,
                  isArabic: widget.isArabic,
                  isDark: widget.isDark,
                  hint: t('المدينة', 'City'),
                  margin: const EdgeInsets.only(bottom: 12),
                ),
                _input(t('العنوان', 'Address'), addressController),
                _input(
                  t('ZIP Code - اختياري', 'ZIP Code - optional'),
                  zipController,
                ),
              ],
              if (isCoupon) _couponOptions(),
              if (selectedCategory != 'سؤال') _contactOptions(),
              if (selectedCategory != 'سؤال' && (allowCall || allowSms))
                _input(t('رقم الهاتف', 'Phone Number'), phoneController),
              if (!isRestaurantOrStore)
                _input(
                  priceHint(),
                  priceController,
                  keyboardType: TextInputType.number,
                  prefixText: '\$ ',
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
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
        : t('المقاس الأفضل: 900 × 500 بكسل', 'Best size: 900 x 500 px');
    final placementText = isVipAdRequest
        ? t(
            'هذا الإعلان يظهر أعلى الصفحة الرئيسية كأقوى مساحة إعلانية.',
            'This ad appears at the top of the home page as the strongest ad spot.',
          )
        : t(
            'هذا الإعلان يظهر ضمن قسم الإعلانات المميزة أسفل إعلان VIP.',
            'This ad appears in the featured ads section below the VIP ad.',
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
                      : t('إعلان مميز', 'Featured Ad'),
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

  Widget _contactSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
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
      onTap: () => changeCategory(value),
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

  Widget _input(
    String hint,
    TextEditingController controller, {
    int lines = 1,
    TextInputType? keyboardType,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: lines,
        inputFormatters: inputFormatters,
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
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
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
