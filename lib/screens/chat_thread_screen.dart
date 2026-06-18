import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class ChatThreadScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;
  final String chatId;
  final String adTitle;
  final String otherUserName;

  const ChatThreadScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    required this.chatId,
    required this.adTitle,
    required this.otherUserName,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final messageController = TextEditingController();
  bool isSending = false;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
            'unreadBy.${user.uid}': false,
            'lastReadAt.${user.uid}': FieldValue.serverTimestamp(),
          });
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || isSending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage(t('سجّل الدخول لإرسال رسالة', 'Login to send a message'));
      return;
    }

    setState(() => isSending = true);

    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId);
      final chatDoc = await chatRef.get();
      final data = chatDoc.data() ?? {};
      final participantIds = List<String>.from(data['participantIds'] ?? []);
      final otherIds = participantIds.where((id) => id != user.uid).toList();
      final profile = await _currentUserProfile(user);
      final senderName = profile['name'] ?? t('مستخدم يا هلا', 'Yahala user');
      final senderPhoto = profile['photoUrl'] ?? '';
      final update = <String, dynamic>{
        'lastMessage': text,
        'lastSenderId': user.uid,
        'lastSenderName': senderName,
        'participantNames.${user.uid}': senderName,
        'participantPhotos.${user.uid}': senderPhoto,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      for (final id in otherIds) {
        update['unreadBy.$id'] = true;
      }
      update['unreadBy.${user.uid}'] = false;

      final messageRef = chatRef.collection('messages').doc();
      final batch = FirebaseFirestore.instance.batch();

      batch.set(messageRef, {
        'text': text,
        'senderId': user.uid,
        'senderName': senderName,
        'senderPhotoUrl': senderPhoto,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(chatRef, update);

      await batch.commit();

      messageController.clear();
    } catch (_) {
      if (mounted) {
        _showMessage(t('تعذر إرسال الرسالة', 'Could not send message'));
      }
    }

    if (mounted) setState(() => isSending = false);
  }

  Future<Map<String, String>> _currentUserProfile(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      return {
        'name': _cleanName(data['name']?.toString() ?? user.displayName ?? ''),
        'photoUrl': data['photoUrl']?.toString() ?? user.photoURL ?? '',
      };
    } catch (_) {
      return {
        'name': _cleanName(user.displayName ?? ''),
        'photoUrl': user.photoURL ?? '',
      };
    }
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
          title: _chatHeader(),
        ),
        body: Column(
          children: [
            Expanded(child: _messagesList()),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _messagesList() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .snapshots(),
      builder: (context, chatSnapshot) {
        final chatData = chatSnapshot.data?.data() as Map<String, dynamic>?;
        final currentUser = FirebaseAuth.instance.currentUser;
        final unread = Map<String, dynamic>.from(chatData?['unreadBy'] ?? {});

        if (currentUser != null && unread[currentUser.uid] == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .collection('messages')
              .orderBy('createdAt')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  t('تعذر تحميل المحادثة', 'Could not load chat'),
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(yaHalaGreen),
                ),
              );
            }

            final messages = snapshot.data!.docs;
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            String? latestOwnMessageId;

            if (currentUserId != null) {
              for (final message in messages) {
                final data = message.data() as Map<String, dynamic>;
                if (data['senderId'] == currentUserId) {
                  latestOwnMessageId = message.id;
                }
              }
            }

            if (messages.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    t(
                      'ابدأ المحادثة برسالة قصيرة',
                      'Start the conversation with a quick message',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              );
            }

            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(14),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final doc = messages[messages.length - 1 - index];
                final data = doc.data() as Map<String, dynamic>;
                return _messageBubble(
                  data,
                  chatData,
                  showReadStatus: doc.id == latestOwnMessageId,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _chatHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .snapshots(),
      builder: (context, snapshot) {
        final user = FirebaseAuth.instance.currentUser;
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final names = Map<String, dynamic>.from(
          data?['participantNames'] ?? {},
        );
        final photos = Map<String, dynamic>.from(
          data?['participantPhotos'] ?? {},
        );
        final name = names.entries
            .firstWhere(
              (entry) => entry.key != user?.uid,
              orElse: () => MapEntry('', widget.otherUserName),
            )
            .value
            .toString();
        final photo = photos.entries
            .firstWhere(
              (entry) => entry.key != user?.uid,
              orElse: () => const MapEntry('', ''),
            )
            .value
            .toString();
        final cleanName = _cleanName(name);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _avatar(cleanName, photo),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cleanName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  if (widget.adTitle.isNotEmpty)
                    Text(
                      widget.adTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _messageBubble(
    Map<String, dynamic> data,
    Map<String, dynamic>? chat, {
    required bool showReadStatus,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    final isMine = data['senderId'] == user?.uid;
    final text = data['text']?.toString() ?? '';
    final time = data['createdAt'];
    final isRead = isMine && _isReadByOther(data, chat);
    final names = Map<String, dynamic>.from(chat?['participantNames'] ?? {});
    final senderName = _cleanName(
      names[data['senderId']]?.toString() ??
          data['senderName']?.toString() ??
          '',
    );

    return Align(
      alignment: isMine
          ? (widget.isArabic ? Alignment.centerRight : Alignment.centerLeft)
          : (widget.isArabic ? Alignment.centerLeft : Alignment.centerRight),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, bottom: 3),
              child: Text(
                senderName,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 310),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isMine
                  ? yaHalaGreen
                  : (widget.isDark ? cardColor : const Color(0xFFF1F1F1)),
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(18),
                topEnd: const Radius.circular(18),
                bottomStart: Radius.circular(isMine ? 18 : 5),
                bottomEnd: Radius.circular(isMine ? 5 : 18),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isMine
                    ? Colors.white
                    : (widget.isDark ? Colors.white : Colors.black87),
                height: 1.35,
                fontSize: 15,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeLabel(time),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
                if (showReadStatus && isRead) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.done_all, color: yaHalaGreen, size: 13),
                  const SizedBox(width: 2),
                  Text(
                    t('مقروء', 'Read'),
                    style: const TextStyle(
                      color: yaHalaGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _avatar(String name, String photoUrl) {
    final letter = name.trim().isEmpty
        ? 'ي'
        : String.fromCharCode(name.trim().runes.first);

    return CircleAvatar(
      radius: 18,
      backgroundColor: yaHalaGold,
      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl.isEmpty
          ? Text(
              letter,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }

  String _cleanName(String value) {
    final name = value.trim();
    if (name.isEmpty || name.contains('@')) {
      return t('مستخدم يا هلا', 'Yahala user');
    }
    return name;
  }

  String _timeLabel(dynamic value) {
    if (value is! Timestamp) return '';

    final date = value.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  bool _isReadByOther(
    Map<String, dynamic> message,
    Map<String, dynamic>? chat,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    final createdAt = message['createdAt'];

    if (user == null || createdAt is! Timestamp) return false;

    final reads = Map<String, dynamic>.from(chat?['lastReadAt'] ?? {});

    for (final entry in reads.entries) {
      if (entry.key == user.uid) continue;

      final value = entry.value;
      if (value is Timestamp &&
          value.millisecondsSinceEpoch >= createdAt.millisecondsSinceEpoch) {
        return true;
      }
    }

    return false;
  }

  Widget _composer() {
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
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: t('اكتب رسالة...', 'Write a message...'),
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: widget.isDark ? bgDark : const Color(0xFFF3F3F3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              width: 48,
              child: ElevatedButton(
                onPressed: isSending ? null : _sendMessage,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: yaHalaGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
