import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'add_question_screen.dart';
import 'question_details_screen.dart';
import '../utils/ad_promotion.dart';
import '../widgets/favorite_button.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class CommunityScreen extends StatelessWidget {
  final bool isArabic;
  final bool isDark;
  final bool showAppBar;

  const CommunityScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    this.showAppBar = true,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? bgDark : Colors.white,
        appBar: showAppBar
            ? AppBar(
                backgroundColor: yaHalaGreen,
                elevation: 0,
                centerTitle: true,
                title: Text(
                  t('اسأل الجالية', 'Ask Community'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : null,
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: yaHalaGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddQuestionScreen(isArabic: isArabic, isDark: isDark),
                    ),
                  );
                },
                icon: const Icon(Icons.add_comment, color: Colors.white),
                label: Text(
                  t('إضافة سؤال', 'Ask Question'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ads')
                  .where('category', isEqualTo: 'سؤال')
                  .where('status', isEqualTo: 'approved')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.red),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(yaHalaGreen),
                      ),
                    ),
                  );
                }

                final questions = sortAdsByPromotion(snapshot.data!.docs);

                if (questions.isEmpty) {
                  return Text(
                    t('لا توجد أسئلة بعد', 'No questions yet'),
                    style: const TextStyle(color: Colors.grey),
                  );
                }

                return Column(
                  children: questions.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _questionCard(context, doc.id, data);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionCard(
    BuildContext context,
    String questionId,
    Map<String, dynamic> data,
  ) {
    final title =
        data['title']?.toString() ?? t('سؤال بدون عنوان', 'Untitled Question');
    final description = data['description']?.toString() ?? '';
    final likesCount = data['likesCount']?.toString() ?? '0';
    final commentsCount = data['commentsCount']?.toString() ?? '0';
    final commentsEnabled = data['commentsEnabled'] != false;
    final anonymous = data['anonymous'] == true;
    final authorName = data['authorName']?.toString() ?? '';
    final author = anonymous || authorName.isEmpty
        ? t('عضو من الجالية', 'Community member')
        : authorName;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuestionDetailsScreen(
              isArabic: isArabic,
              isDark: isDark,
              questionId: questionId,
              data: data,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? cardColor : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FavoriteButton(
                  adId: questionId,
                  data: data,
                  isArabic: isArabic,
                  savedColor: Colors.redAccent,
                  unsavedColor: isDark ? Colors.white70 : yaHalaGreen,
                  iconSize: 24,
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, color: Colors.grey, size: 18),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    author,
                    style: const TextStyle(color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.thumb_up_outlined,
                  color: yaHalaGold,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(likesCount, style: const TextStyle(color: Colors.grey)),
                const SizedBox(width: 12),
                const Icon(
                  Icons.comment_outlined,
                  color: Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(commentsCount, style: const TextStyle(color: Colors.grey)),
                if (!commentsEnabled) ...[
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.comments_disabled,
                    color: Colors.grey,
                    size: 18,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
