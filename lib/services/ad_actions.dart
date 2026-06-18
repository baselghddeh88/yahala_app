import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/auth_choice_screen.dart';
import '../screens/chat_thread_screen.dart';

class AdActions {
  static String cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  static Future<void> callPhone(
    BuildContext context,
    String phone, {
    required bool isArabic,
  }) async {
    final clean = cleanPhone(phone);
    if (clean.isEmpty) return;

    final launched = await launchUrl(
      Uri(scheme: 'tel', path: clean),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showMessage(
        context,
        isArabic ? 'تعذر فتح الاتصال' : 'Could not open call',
      );
    }
  }

  static Future<void> sendSms(
    BuildContext context,
    String phone, {
    required bool isArabic,
  }) async {
    final clean = cleanPhone(phone);
    if (clean.isEmpty) return;

    final launched = await launchUrl(
      Uri(scheme: 'sms', path: clean),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showMessage(
        context,
        isArabic ? 'تعذر فتح الرسائل' : 'Could not open SMS',
      );
    }
  }

  static Future<void> addFavorite(
    BuildContext context, {
    required String adId,
    required Map<String, dynamic> data,
    required bool isArabic,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        context,
        isArabic ? 'سجّل الدخول لإضافة المفضلة' : 'Login to add favorites',
      );
      return;
    }

    if (adId.isEmpty) {
      _showMessage(
        context,
        isArabic ? 'تعذر حفظ الإعلان' : 'Could not save this ad',
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(adId)
          .set({
            ...data,
            'adId': adId,
            'savedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      if (!context.mounted) return;

      _showMessage(
        context,
        isArabic ? 'تعذر حفظ المفضلة' : 'Could not save favorite',
      );
      return;
    }

    if (!context.mounted) return;

    _showMessage(
      context,
      isArabic ? 'تمت الإضافة للمفضلة' : 'Added to favorites',
    );
  }

  static Future<void> toggleFavorite(
    BuildContext context, {
    required String adId,
    required Map<String, dynamic> data,
    required bool isArabic,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        context,
        isArabic ? 'سجّل الدخول لإضافة المفضلة' : 'Login to add favorites',
      );
      return;
    }

    if (adId.isEmpty) {
      _showMessage(
        context,
        isArabic ? 'تعذر حفظ الإعلان' : 'Could not save this ad',
      );
      return;
    }

    final favoriteRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(adId);

    try {
      final favoriteDoc = await favoriteRef.get();

      if (favoriteDoc.exists) {
        await favoriteRef.delete();
        if (context.mounted) {
          _showMessage(
            context,
            isArabic ? 'تمت الإزالة من المفضلة' : 'Removed from favorites',
          );
        }
        return;
      }

      await favoriteRef.set({
        ...data,
        'adId': adId,
        'savedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (context.mounted) {
        _showMessage(
          context,
          isArabic ? 'تمت الإضافة للمفضلة' : 'Added to favorites',
        );
      }
    } catch (_) {
      if (!context.mounted) return;

      _showMessage(
        context,
        isArabic ? 'تعذر تحديث المفضلة' : 'Could not update favorite',
      );
    }
  }

  static Future<void> openInAppChat(
    BuildContext context, {
    required String adId,
    required Map<String, dynamic> data,
    required bool isArabic,
    required bool isDark,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AuthChoiceScreen(isArabic: isArabic, isDark: isDark),
        ),
      );
      return;
    }

    final ownerId = data['userId']?.toString() ?? '';
    if (adId.isEmpty || ownerId.isEmpty) {
      _showMessage(
        context,
        isArabic ? 'تعذر فتح المحادثة' : 'Could not open chat',
      );
      return;
    }

    if (ownerId == user.uid) {
      _showMessage(
        context,
        isArabic ? 'هذا إعلانك أنت' : 'This is your own ad',
      );
      return;
    }

    try {
      final users = FirebaseFirestore.instance.collection('users');
      final currentDoc = await users.doc(user.uid).get();
      final currentData = currentDoc.data() ?? {};
      final ownerName = _safeName(
        data['authorName']?.toString(),
        data['userEmail']?.toString(),
      );
      final currentName = _safeName(
        currentData['name']?.toString(),
        user.displayName,
      );
      final ownerPhoto = data['authorPhotoUrl']?.toString() ?? '';
      final currentPhoto =
          currentData['photoUrl']?.toString() ?? user.photoURL ?? '';
      final participantIds = [user.uid, ownerId]..sort();
      final chatId = '${adId}_${participantIds.join('_')}';
      final title = data['title']?.toString() ?? '';
      final imageUrl = data['imageUrl']?.toString() ?? '';

      final chatData = <String, dynamic>{
        'adId': adId,
        'adTitle': title,
        'adImageUrl': imageUrl,
        'adCategory': data['category']?.toString() ?? '',
        'ownerId': ownerId,
        'ownerPhotoUrl': ownerPhoto,
        'participantIds': participantIds,
        'participantNames': {user.uid: currentName, ownerId: ownerName},
        'participantPhotos': {user.uid: currentPhoto, ownerId: ownerPhoto},
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId);

      await chatRef.set(chatData, SetOptions(merge: true));
      await chatRef.update({
        'unreadBy.${user.uid}': false,
        'lastReadAt.${user.uid}': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            isArabic: isArabic,
            isDark: isDark,
            chatId: chatId,
            adTitle: title,
            otherUserName: ownerName,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      _showMessage(
        context,
        error.toString().contains('permission-denied')
            ? (isArabic
                  ? 'صلاحيات الشات تحتاج تحديث'
                  : 'Chat permissions need updating')
            : (isArabic ? 'تعذر فتح المحادثة' : 'Could not open chat'),
      );
    }
  }

  static String _safeName(String? primary, String? fallback) {
    final first = primary?.trim() ?? '';
    if (first.isNotEmpty && !first.contains('@')) return first;

    final second = fallback?.trim() ?? '';
    if (second.isNotEmpty && !second.contains('@')) return second;

    return 'مستخدم يا هلا';
  }

  static void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
