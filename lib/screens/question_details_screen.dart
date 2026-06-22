import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/ad_actions.dart';
import '../widgets/favorite_button.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class QuestionDetailsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;
  final String questionId;
  final Map<String, dynamic> data;

  const QuestionDetailsScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    required this.questionId,
    required this.data,
  });

  @override
  State<QuestionDetailsScreen> createState() => _QuestionDetailsScreenState();
}

class _QuestionDetailsScreenState extends State<QuestionDetailsScreen> {
  final commentController = TextEditingController();
  bool anonymousComment = false;
  bool isSending = false;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _questionRef =>
      FirebaseFirestore.instance.collection('ads').doc(widget.questionId);

  Future<void> toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage(t('سجّل الدخول للإعجاب', 'Login to like'));
      return;
    }

    final likeRef = _questionRef.collection('likes').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final likeDoc = await transaction.get(likeRef);
      final questionDoc = await transaction.get(_questionRef);
      final count = questionDoc.data()?['likesCount'] as int? ?? 0;

      if (likeDoc.exists) {
        transaction.delete(likeRef);
        transaction.update(_questionRef, {
          'likesCount': count > 0 ? count - 1 : 0,
        });
      } else {
        transaction.set(likeRef, {
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(_questionRef, {'likesCount': count + 1});
      }
    });
  }

  Future<void> addComment() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final commentsEnabled = widget.data['commentsEnabled'] != false;
    if (!commentsEnabled) {
      _showMessage(t('التعليقات مغلقة لهذا السؤال', 'Comments are closed'));
      return;
    }

    final text = commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage(t('سجّل الدخول للتعليق', 'Login to comment'));
      return;
    }

    setState(() => isSending = true);

    try {
      final authorName = anonymousComment
          ? ''
          : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!
                : user.email ?? '');

      await _questionRef.collection('comments').add({
        'text': text,
        'userId': user.uid,
        'authorName': authorName,
        'anonymous': anonymousComment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _questionRef.update({'commentsCount': FieldValue.increment(1)});

      commentController.clear();
    } catch (_) {
      if (mounted) {
        _showMessage(t('تعذر إرسال التعليق', 'Could not send comment'));
      }
    }

    if (mounted) setState(() => isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title']?.toString() ?? '';
    final description = widget.data['description']?.toString() ?? '';
    final anonymous = widget.data['anonymous'] == true;
    final authorName = widget.data['authorName']?.toString() ?? '';
    final fallbackAuthor = t('عضو من الجالية', 'Community member');
    final commentsEnabled = widget.data['commentsEnabled'] != false;

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: widget.isDark ? bgDark : Colors.white,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          centerTitle: true,
          title: Text(
            t('السؤال', 'Question'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            FavoriteButton(
              adId: widget.questionId,
              data: widget.data,
              isArabic: widget.isArabic,
              savedColor: Colors.redAccent,
              unsavedColor: Colors.white,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _questionHeader(
                    title: title,
                    description: description,
                    author: anonymous || authorName.isEmpty
                        ? fallbackAuthor
                        : authorName,
                  ),
                  const SizedBox(height: 18),
                  _commentsList(),
                ],
              ),
            ),
            if (commentsEnabled) _commentComposer() else _commentsClosedBox(),
          ],
        ),
      ),
    );
  }

  Widget _questionHeader({
    required String title,
    required String description,
    required String author,
  }) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: _questionRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final likesCount =
            data?['likesCount'] ?? widget.data['likesCount'] ?? 0;
        final commentsCount =
            data?['commentsCount'] ?? widget.data['commentsCount'] ?? 0;
        final phone =
            data?['phone']?.toString() ??
            widget.data['phone']?.toString() ??
            '';
        final hasContactOptions =
            (data ?? widget.data).containsKey('allowCall') ||
            (data ?? widget.data).containsKey('allowSms') ||
            (data ?? widget.data).containsKey('allowInAppMessage');
        final allowCall = hasContactOptions
            ? (data?['allowCall'] ?? widget.data['allowCall']) == true
            : false;
        final allowSms = hasContactOptions
            ? (data?['allowSms'] ?? widget.data['allowSms']) == true
            : false;
        final allowInAppMessage =
            (data?['allowInAppMessage'] ?? widget.data['allowInAppMessage']) ==
            true;
        final commentsEnabled =
            (data?['commentsEnabled'] ?? widget.data['commentsEnabled']) !=
            false;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty
                    ? t('سؤال بدون عنوان', 'Untitled Question')
                    : title,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.grey, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      author,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  if (user == null)
                    _likeButton(false, likesCount)
                  else
                    StreamBuilder<DocumentSnapshot>(
                      stream: _questionRef
                          .collection('likes')
                          .doc(user.uid)
                          .snapshots(),
                      builder: (context, likeSnapshot) {
                        return _likeButton(
                          likeSnapshot.data?.exists == true,
                          likesCount,
                        );
                      },
                    ),
                  const SizedBox(width: 10),
                  const Icon(Icons.comment, color: Colors.grey, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$commentsCount',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              if (!commentsEnabled) ...[
                const SizedBox(height: 12),
                _infoChip(
                  Icons.comments_disabled,
                  t('التعليقات مغلقة', 'Comments closed'),
                ),
              ],
              if (allowCall || allowSms || allowInAppMessage) ...[
                const SizedBox(height: 14),
                _contactButtons(
                  phone: phone,
                  allowCall: allowCall,
                  allowSms: allowSms,
                  allowInAppMessage: allowInAppMessage,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _likeButton(bool liked, Object likesCount) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: toggleLike,
      child: Row(
        children: [
          Icon(
            liked ? Icons.thumb_up : Icons.thumb_up_outlined,
            color: liked ? yaHalaGold : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text('$likesCount', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: yaHalaGold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: yaHalaGold),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: yaHalaGold,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactButtons({
    required String phone,
    required bool allowCall,
    required bool allowSms,
    required bool allowInAppMessage,
  }) {
    final showCall = allowCall && phone.trim().isNotEmpty;
    final showSms = allowSms && phone.trim().isNotEmpty;

    return Row(
      children: [
        if (showCall)
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: yaHalaGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => AdActions.callPhone(
                context,
                phone,
                isArabic: widget.isArabic,
              ),
              icon: const Icon(Icons.phone, color: Colors.white),
              label: Text(
                t('اتصال', 'Call'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        if (showCall && (showSms || allowInAppMessage))
          const SizedBox(width: 8),
        if (showSms)
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: yaHalaGold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () =>
                  AdActions.sendSms(context, phone, isArabic: widget.isArabic),
              icon: const Icon(Icons.sms, color: Colors.white),
              label: Text(
                t('رسالة', 'SMS'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        if (showSms && allowInAppMessage) const SizedBox(width: 8),
        if (allowInAppMessage)
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => AdActions.openInAppChat(
                context,
                adId: widget.questionId,
                data: widget.data,
                isArabic: widget.isArabic,
                isDark: widget.isDark,
              ),
              icon: const Icon(Icons.chat, color: Colors.white),
              label: Text(
                t('التطبيق', 'App'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _commentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _questionRef
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final comments = snapshot.data!.docs;

        if (comments.isEmpty) {
          return Text(
            t('لا توجد تعليقات بعد', 'No comments yet'),
            style: const TextStyle(color: Colors.grey),
          );
        }

        return Column(
          children: comments.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final text = data['text']?.toString() ?? '';
            final anonymous = data['anonymous'] == true;
            final author = data['authorName']?.toString() ?? '';

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anonymous || author.isEmpty
                        ? t('عضو من الجالية', 'Community member')
                        : author,
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(text, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _commentComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: widget.isDark ? cardColor : Colors.white,
          border: Border(
            top: BorderSide(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: anonymousComment,
              activeThumbColor: yaHalaGold,
              title: Text(
                t('تعليق بدون اسم', 'Comment anonymously'),
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black,
                  fontSize: 13,
                ),
              ),
              onChanged: (value) => setState(() => anonymousComment = value),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: t('اكتب تعليق...', 'Write a comment...'),
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: widget.isDark
                          ? bgDark
                          : const Color(0xFFF3F3F3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: yaHalaGreen),
                  onPressed: isSending ? null : addComment,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _commentsClosedBox() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: BoxDecoration(
          color: widget.isDark ? cardColor : Colors.white,
          border: Border(
            top: BorderSide(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Text(
          t('صاحب السؤال أغلق التعليقات', 'The author closed comments'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
