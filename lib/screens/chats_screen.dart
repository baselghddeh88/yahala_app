import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_choice_screen.dart';
import 'chat_thread_screen.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class ChatsScreen extends StatelessWidget {
  final bool isArabic;
  final bool isDark;
  final bool showAppBar;

  const ChatsScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    this.showAppBar = true,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return AuthChoiceScreen(isArabic: isArabic, isDark: isDark);
    }

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? bgDark : Colors.white,
        appBar: showAppBar
            ? AppBar(
                backgroundColor: yaHalaGreen,
                centerTitle: true,
                title: Text(
                  t('المحادثات', 'Chats'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : null,
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('participantIds', arrayContains: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  t('تعذر تحميل المحادثات', 'Could not load chats'),
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

            final chats = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final ad = a.data() as Map<String, dynamic>;
                final bd = b.data() as Map<String, dynamic>;
                final at = ad['updatedAt'];
                final bt = bd['updatedAt'];
                final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                return bm.compareTo(am);
              });

            if (chats.isEmpty) {
              return _emptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final doc = chats[index];
                final data = doc.data() as Map<String, dynamic>;
                return _chatTile(context, doc.id, data, user.uid);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 78,
              width: 78,
              decoration: BoxDecoration(
                color: yaHalaGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: yaHalaGreen,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('لا توجد محادثات بعد', 'No chats yet'),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(
                'أي إعلان فيه تواصل عبر التطبيق سيظهر هنا بعد أول رسالة.',
                'Ads with in-app contact will appear here after the first message.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatTile(
    BuildContext context,
    String chatId,
    Map<String, dynamic> data,
    String currentUserId,
  ) {
    final title = data['adTitle']?.toString() ?? t('إعلان', 'Ad');
    final imageUrl = data['adImageUrl']?.toString() ?? '';
    final ownerPhotoUrl = data['ownerPhotoUrl']?.toString() ?? '';
    final ownerId = data['ownerId']?.toString() ?? '';
    final lastMessage = data['lastMessage']?.toString() ?? '';
    final updatedAt = data['updatedAt'];
    final names = Map<String, dynamic>.from(data['participantNames'] ?? {});
    final photos = Map<String, dynamic>.from(data['participantPhotos'] ?? {});
    final otherName = names.entries
        .firstWhere(
          (entry) => entry.key != currentUserId,
          orElse: () => const MapEntry('', ''),
        )
        .value
        .toString();
    final otherPhoto = photos.entries
        .firstWhere(
          (entry) => entry.key != currentUserId,
          orElse: () => const MapEntry('', ''),
        )
        .value
        .toString();
    final ownerName = _cleanName(names[ownerId]?.toString() ?? otherName);
    final ownerPhoto = ownerPhotoUrl.isNotEmpty
        ? ownerPhotoUrl
        : (photos[ownerId]?.toString() ?? otherPhoto);
    final hasUnread = _hasUnreadChat(data, currentUserId);
    final cleanName = _cleanName(otherName);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatThreadScreen(
              isArabic: isArabic,
              isDark: isDark,
              chatId: chatId,
              adTitle: title,
              otherUserName: cleanName,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? cardColor : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasUnread
                ? yaHalaGold
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _adThumb(imageUrl),
                PositionedDirectional(
                  end: -4,
                  bottom: -4,
                  child: _smallOwnerAvatar(ownerName, ownerPhoto),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cleanName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: yaHalaGold, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    lastMessage.isEmpty
                        ? t('لا توجد رسائل بعد', 'No messages yet')
                        : lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasUnread
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.grey,
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeLabel(updatedAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 10),
                if (hasUnread)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 10,
                        width: 10,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: yaHalaGold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          t('جديد', 'New'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _adThumb(String imageUrl) {
    return Container(
      height: 64,
      width: 64,
      decoration: BoxDecoration(
        color: yaHalaGold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? const Icon(Icons.campaign, color: yaHalaGold, size: 28)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.campaign, color: yaHalaGold, size: 28),
            ),
    );
  }

  Widget _smallOwnerAvatar(String name, String photoUrl) {
    final letter = name.trim().isEmpty
        ? 'ي'
        : String.fromCharCode(name.trim().runes.first);

    return Container(
      height: 28,
      width: 28,
      decoration: BoxDecoration(
        color: isDark ? bgDark : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? cardColor : const Color(0xFFF3F3F3),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl.isNotEmpty
          ? Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _smallOwnerLetter(letter),
            )
          : _smallOwnerLetter(letter),
    );
  }

  Widget _smallOwnerLetter(String letter) {
    return Container(
      color: yaHalaGreen,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
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
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return t('الآن', 'Now');
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${date.month}/${date.day}';
  }

  bool _hasUnreadChat(Map<String, dynamic> data, String userId) {
    final unread = Map<String, dynamic>.from(data['unreadBy'] ?? {});
    if (_isUnreadValue(unread[userId])) return true;

    final lastSenderId = data['lastSenderId']?.toString();
    final updatedAt = data['updatedAt'];
    if (lastSenderId == null ||
        lastSenderId == userId ||
        updatedAt is! Timestamp) {
      return false;
    }

    final reads = Map<String, dynamic>.from(data['lastReadAt'] ?? {});
    final lastReadAt = reads[userId];
    return lastReadAt is! Timestamp ||
        lastReadAt.millisecondsSinceEpoch < updatedAt.millisecondsSinceEpoch;
  }

  bool _isUnreadValue(dynamic value) {
    return value == true || value == 'true' || value == 1;
  }
}
