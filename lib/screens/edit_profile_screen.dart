import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class EditProfileScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;

  const EditProfileScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  File? selectedImage;
  String photoUrl = '';

  bool isLoading = false;
  bool isSaving = false;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);

    if (pickedFile == null) return;

    setState(() {
      selectedImage = File(pickedFile.path);
    });
  }

  Future<void> chooseImageSource() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: widget.isDark ? cardColor : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera, color: yaHalaGreen),
                  title: Text(
                    t('التقاط صورة بالكاميرا', 'Take a photo'),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: yaHalaGold),
                  title: Text(
                    t('اختيار من الجهاز', 'Choose from device'),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      nameController.text = data['name']?.toString() ?? '';
      phoneController.text = data['phone']?.toString() ?? '';
      photoUrl = data['photoUrl']?.toString() ?? '';
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<String> uploadProfileImage(String uid) async {
    if (selectedImage == null) return photoUrl;

    final ref = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(uid)
        .child('profile.jpg');

    await ref.putFile(selectedImage!);

    return await ref.getDownloadURL();
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSaving = true);

    final uploadedPhotoUrl = await uploadProfileImage(user.uid);
    await user.updateDisplayName(nameController.text.trim());
    if (uploadedPhotoUrl.isNotEmpty) {
      await user.updatePhotoURL(uploadedPhotoUrl);
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'email': user.email ?? '',
      'photoUrl': uploadedPhotoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    setState(() => isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('تم حفظ البيانات', 'Profile saved'))),
    );

    Navigator.pop(context);
  }

  Future<void> resetPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (email == null || email.isEmpty) return;

    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'تم إرسال رابط تغيير كلمة المرور إلى بريدك',
            'Password reset link sent to your email',
          ),
        ),
      ),
    );
  }

  ImageProvider? profileImageProvider() {
    if (selectedImage != null) {
      return FileImage(selectedImage!);
    }

    if (photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final imageProvider = profileImageProvider();

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: widget.isDark ? bgDark : Colors.white,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          centerTitle: true,
          title: Text(
            t('تعديل الحساب', 'Edit Profile'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: chooseImageSource,
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: yaHalaGreen,
                        backgroundImage: imageProvider,
                        child: imageProvider == null
                            ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 46,
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      t('اضغط لتغيير الصورة', 'Tap to change photo'),
                      style: const TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 24),

                    _input(
                      controller: nameController,
                      hint: t('الاسم', 'Name'),
                      icon: Icons.person,
                    ),

                    const SizedBox(height: 14),

                    _input(
                      controller: phoneController,
                      hint: t('رقم الهاتف', 'Phone Number'),
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 14),

                    _readOnlyBox(text: user?.email ?? '', icon: Icons.email),

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
                        onPressed: isSaving ? null : saveProfile,
                        child: isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                t('حفظ التعديلات', 'Save Changes'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextButton.icon(
                      onPressed: resetPassword,
                      icon: const Icon(Icons.lock_reset, color: yaHalaGreen),
                      label: Text(
                        t('تغيير كلمة المرور', 'Change Password'),
                        style: const TextStyle(
                          color: yaHalaGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
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

  Widget _readOnlyBox({required String text, required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
