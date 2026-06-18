import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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
  final phoneController = TextEditingController();
  final priceController = TextEditingController();
  final ImagePicker picker = ImagePicker();
  final List<File> selectedImages = [];
  late List<String> existingImageUrls;

  bool isSaving = false;
  int get maxImages {
    final category = widget.data['category']?.toString() ?? '';
    return category == 'سكن' || category == 'مطاعم ومحلات' ? 5 : 1;
  }

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();

    titleController.text = widget.data['title']?.toString() ?? '';
    descriptionController.text = widget.data['description']?.toString() ?? '';
    cityController.text = widget.data['city']?.toString() ?? '';
    phoneController.text = widget.data['phone']?.toString() ?? '';
    priceController.text = widget.data['price']?.toString() ?? '';
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
    phoneController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> saveAd() async {
    if (titleController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty ||
        cityController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('عبّي الحقول المطلوبة', 'Fill required fields')),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    final uploadedImages = await uploadNewImages();
    final allImages = [...existingImageUrls, ...uploadedImages];

    await FirebaseFirestore.instance
        .collection('ads')
        .doc(widget.docId)
        .update({
          'title': titleController.text.trim(),
          'description': descriptionController.text.trim(),
          'city': cityController.text.trim(),
          'phone': phoneController.text.trim(),
          'price': priceController.text.trim(),
          'imageUrl': allImages.isNotEmpty ? allImages.first : '',
          'imageUrls': allImages,
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });

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
            children: [
              _imageEditor(),
              const SizedBox(height: 18),
              _input(
                controller: titleController,
                hint: t('العنوان', 'Title'),
                icon: Icons.title,
              ),
              const SizedBox(height: 14),
              _input(
                controller: descriptionController,
                hint: t('الوصف', 'Description'),
                icon: Icons.description,
                maxLines: 4,
              ),
              const SizedBox(height: 14),
              CityPickerField(
                controller: cityController,
                isArabic: widget.isArabic,
                isDark: widget.isDark,
                hint: t('المدينة', 'City'),
              ),
              const SizedBox(height: 14),
              _input(
                controller: phoneController,
                hint: t('رقم الهاتف', 'Phone Number'),
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              _input(
                controller: priceController,
                hint: t('السعر / الراتب', 'Price / Salary'),
                icon: Icons.attach_money,
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

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hint,
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
