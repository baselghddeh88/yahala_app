import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../screens/ad_details_screen.dart';
import '../screens/chat_thread_screen.dart';
import '../screens/question_details_screen.dart';

class NotificationService {
  static String? pendingAdId;
  static String? pendingChatId;
  static String pendingChatTitle = '';
  static String pendingChatUserName = '';
  static bool _shouldOpenLatestApprovedAd = false;
  static bool _isOpeningAd = false;
  static bool _isOpeningChat = false;
  static bool openedAdFromNotification = false;
  static bool _isListeningToNotificationClicks = false;
  static const _nativeNotificationChannel = MethodChannel(
    'yahala/notifications',
  );

  static Future<void> saveFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      String? token;

      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        for (int i = 0; i < 5; i++) {
          final apnsToken = await FirebaseMessaging.instance.getAPNSToken();

          if (apnsToken != null) {
            token = await FirebaseMessaging.instance.getToken();
            break;
          }

          await Future.delayed(const Duration(seconds: 1));
        }
      } else {
        token = await FirebaseMessaging.instance.getToken();
      }

      if (token == null) {
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static void saveFcmTokenInBackground() {
    unawaited(saveFcmToken());
  }

  static void listenToTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': newToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  static void listenToNotificationClicks() {
    if (_isListeningToNotificationClicks) return;

    _isListeningToNotificationClicks = true;

    _nativeNotificationChannel.setMethodCallHandler((call) async {
      if (call.method != 'openAd') return;

      final adId = call.arguments?.toString().trim();

      if (adId == null || adId.isEmpty) return;

      pendingAdId = adId;
      await openPendingAdIfAny();
    });

    _nativeNotificationChannel.invokeMethod<String>('getInitialAdId').then((
      adId,
    ) {
      final value = adId?.trim();

      if (value == null || value.isEmpty) return;

      pendingAdId = value;
      openPendingAdIfAny();
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message == null) return;

      _handleNotificationTap(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  static Future<bool> openPendingAdIfAny({int attempt = 0}) async {
    final openedChat = await _openPendingChatIfAny(attempt: attempt);
    if (openedChat) return true;

    final adId = pendingAdId;

    if (adId == null) {
      if (_shouldOpenLatestApprovedAd) {
        return _openLatestApprovedAd(attempt: attempt);
      }

      return openedAdFromNotification;
    }

    if (_isOpeningAd) {
      _retryOpenPendingAd(attempt);
      return false;
    }

    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      _retryOpenPendingAd(attempt);
      return false;
    }

    _isOpeningAd = true;

    pendingAdId = null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('ads')
          .doc(adId)
          .get();

      if (!doc.exists) return false;

      final data = doc.data();

      if (data == null) return false;

      _openDocumentScreen(navigator, adId, data);

      openedAdFromNotification = true;
      return true;
    } catch (_) {
      pendingAdId = adId;
      _retryOpenPendingAd(attempt);
      return false;
    } finally {
      _isOpeningAd = false;
    }
  }

  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    final chatId = _extractChatId(message);

    if (chatId != null) {
      pendingChatId = chatId;
      pendingChatTitle = message.data['adTitle']?.toString() ?? '';
      pendingChatUserName = message.data['senderName']?.toString() ?? '';

      await Future.delayed(const Duration(milliseconds: 300));
      await openPendingAdIfAny();
      return;
    }

    final adId = _extractAdId(message);

    if (adId == null) {
      if (_isApprovalNotification(message)) {
        _shouldOpenLatestApprovedAd = true;

        await Future.delayed(const Duration(milliseconds: 300));
        await openPendingAdIfAny();
      }

      return;
    }

    pendingAdId = adId;

    await Future.delayed(const Duration(milliseconds: 300));
    await openPendingAdIfAny();
  }

  static void _retryOpenPendingAd(int attempt) {
    if (attempt >= 20) return;

    Future.delayed(const Duration(milliseconds: 250), () {
      openPendingAdIfAny(attempt: attempt + 1);
    });
  }

  static Future<bool> _openLatestApprovedAd({int attempt = 0}) async {
    if (_isOpeningAd) {
      _retryOpenPendingAd(attempt);
      return false;
    }

    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      _retryOpenPendingAd(attempt);
      return false;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _retryOpenPendingAd(attempt);
      return false;
    }

    _isOpeningAd = true;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final lastApprovedAdId = userDoc
          .data()?['lastApprovedAdId']
          ?.toString()
          .trim();

      if (lastApprovedAdId == null || lastApprovedAdId.isEmpty) return false;

      final adDoc = await FirebaseFirestore.instance
          .collection('ads')
          .doc(lastApprovedAdId)
          .get();

      if (!adDoc.exists) return false;

      final data = adDoc.data();

      if (data == null) return false;

      _openDocumentScreen(navigator, lastApprovedAdId, data);

      _shouldOpenLatestApprovedAd = false;
      openedAdFromNotification = true;
      return true;
    } catch (_) {
      _retryOpenPendingAd(attempt);
      return false;
    } finally {
      _isOpeningAd = false;
    }
  }

  static Future<bool> _openPendingChatIfAny({int attempt = 0}) async {
    final chatId = pendingChatId;

    if (chatId == null) return false;

    if (_isOpeningChat) {
      _retryOpenPendingAd(attempt);
      return false;
    }

    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      _retryOpenPendingAd(attempt);
      return false;
    }

    _isOpeningChat = true;
    pendingChatId = null;

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      final data = chatDoc.data() ?? {};
      final user = FirebaseAuth.instance.currentUser;
      final names = Map<String, dynamic>.from(data['participantNames'] ?? {});
      final otherName = names.entries
          .firstWhere(
            (entry) => entry.key != user?.uid,
            orElse: () => MapEntry('', pendingChatUserName),
          )
          .value
          .toString();
      final adTitle = data['adTitle']?.toString() ?? pendingChatTitle;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            isArabic: true,
            isDark: false,
            chatId: chatId,
            adTitle: adTitle,
            otherUserName: otherName,
          ),
        ),
      );

      openedAdFromNotification = true;
      pendingChatTitle = '';
      pendingChatUserName = '';
      return true;
    } catch (_) {
      pendingChatId = chatId;
      _retryOpenPendingAd(attempt);
      return false;
    } finally {
      _isOpeningChat = false;
    }
  }

  static String? _extractChatId(RemoteMessage message) {
    final value = message.data['chatId'] ?? message.data['chat_id'];
    final chatId = value?.toString().trim();

    if (chatId == null || chatId.isEmpty) return null;

    return chatId;
  }

  static String? _extractAdId(RemoteMessage message) {
    final value =
        message.data['adId'] ?? message.data['ad_id'] ?? message.data['id'];
    final adId = value?.toString().trim();

    if (adId == null || adId.isEmpty) return null;

    return adId;
  }

  static void _openDocumentScreen(
    NavigatorState navigator,
    String adId,
    Map<String, dynamic> data,
  ) {
    final category = data['category']?.toString();

    if (category == 'سؤال') {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => QuestionDetailsScreen(
            isArabic: true,
            isDark: false,
            questionId: adId,
            data: data,
          ),
        ),
      );
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => AdDetailsScreen(
          isArabic: true,
          isDark: false,
          data: data,
          adId: adId,
        ),
      ),
    );
  }

  static bool _isApprovalNotification(RemoteMessage message) {
    final type = message.data['type']?.toString();
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';

    return type == 'ad_approved' ||
        title.contains('يا هلا') && body.contains('الموافقة');
  }
}
