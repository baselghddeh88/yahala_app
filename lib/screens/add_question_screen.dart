import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/value_formatters.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class AddQuestionScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;

  const AddQuestionScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
  });

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final titleController = TextEditingController();
  final phoneController = TextEditingController();
  bool anonymous = false;
  bool commentsEnabled = true;
  bool allowCall = true;
  bool allowSms = true;
  bool allowInAppMessage = true;
  bool isLoading = false;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void dispose() {
    titleController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> publishQuestion() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final title = titleController.text.trim();
    final phone = cleanPhoneInput(phoneController.text);
    final needsPhone = allowCall || allowSms;

    if (title.isEmpty ||
        (needsPhone && phone.isEmpty) ||
        (!allowCall && !allowSms && !allowInAppMessage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !allowCall && !allowSms && !allowInAppMessage
                ? t(
                    'اختر طريقة تواصل واحدة على الأقل',
                    'Choose at least one contact method',
                  )
                : needsPhone && phone.isEmpty
                ? t('اكتب رقم الهاتف', 'Add a phone number')
                : t('اكتب السؤال', 'Write the question'),
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('ads').add({
        'title': title,
        'description': '',
        'phone': phone,
        'category': 'سؤال',
        'status': 'approved',
        'allowCall': allowCall,
        'allowSms': allowSms,
        'allowInAppMessage': allowInAppMessage,
        'commentsEnabled': commentsEnabled,
        'views': 0,
        'likesCount': 0,
        'commentsCount': 0,
        'anonymous': anonymous,
        'authorName': anonymous
            ? ''
            : (user?.displayName?.trim().isNotEmpty == true
                  ? user!.displayName
                  : user?.email ?? ''),
        'userId': user?.uid ?? '',
        'userEmail': user?.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('تم نشر السؤال', 'Question posted'))),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تعذر نشر السؤال', 'Could not post question')),
        ),
      );
    }

    if (mounted) setState(() => isLoading = false);
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
            t('إضافة سؤال', 'Ask a Question'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _input(
                t('اكتب سؤالك', 'Write your question'),
                titleController,
                lines: 6,
              ),
              _contactOptions(),
              if (allowCall || allowSms)
                _input(
                  t('رقم الهاتف', 'Phone Number'),
                  phoneController,
                  inputFormatters: const [PhoneNumberInputFormatter()],
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                ),
              SwitchListTile(
                value: anonymous,
                activeThumbColor: yaHalaGold,
                title: Text(
                  t('نشر السؤال بدون اسم', 'Post anonymously'),
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onChanged: (value) => setState(() => anonymous = value),
              ),
              SwitchListTile(
                value: commentsEnabled,
                activeThumbColor: yaHalaGreen,
                title: Text(
                  t('السماح بالتعليقات', 'Allow comments'),
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  commentsEnabled
                      ? t('يمكن للجالية الرد على السؤال', 'Community can reply')
                      : t('التعليقات مغلقة على هذا السؤال', 'Comments are off'),
                  style: const TextStyle(color: Colors.grey),
                ),
                onChanged: (value) => setState(() => commentsEnabled = value),
              ),
              const SizedBox(height: 20),
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
                  onPressed: isLoading ? null : publishQuestion,
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
                        ? t('جاري النشر...', 'Posting...')
                        : t('نشر السؤال', 'Post Question'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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

  Widget _input(
    String hint,
    TextEditingController controller, {
    int lines = 1,
    List<TextInputFormatter>? inputFormatters,
    TextDirection? textDirection,
    TextAlign? textAlign,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: lines,
        inputFormatters: inputFormatters,
        textDirection: textDirection,
        textAlign: textAlign ?? TextAlign.start,
        style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
        keyboardType: hint.contains('الهاتف') || hint.contains('Phone')
            ? TextInputType.phone
            : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
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
}
