import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/ad_promotion.dart';
import 'edit_ad_screen.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class MyAdsScreen extends StatelessWidget {
  final bool isArabic;
  final bool isDark;

  const MyAdsScreen({super.key, required this.isArabic, required this.isDark});

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? bgDark : Colors.white,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          title: Text(t('إعلاناتي', 'My Ads')),
        ),
        body: Center(
          child: Text(
            t('سجّل الدخول لعرض إعلاناتك', 'Login to view your ads'),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? bgDark : Colors.white,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          centerTitle: true,
          title: Text(
            t('إعلاناتي', 'My Ads'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('ads')
              .where('userId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: yaHalaGreen),
              );
            }

            final ads = snapshot.data?.docs ?? [];

            if (ads.isEmpty) {
              return Center(
                child: Text(
                  t('لا توجد إعلانات لك بعد', 'You have no ads yet'),
                  style: const TextStyle(color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: ads.length,
              itemBuilder: (context, index) {
                final doc = ads[index];
                final data = doc.data() as Map<String, dynamic>;

                return _myAdCard(context: context, docId: doc.id, data: data);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _myAdCard({
    required BuildContext context,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final title = data['title']?.toString() ?? '';
    final category = data['category']?.toString() ?? '';
    final placement = data['adPlacement']?.toString() ?? '';
    final city = data['city']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'pending';
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final rejectionReason = data['rejectionReason']?.toString() ?? '';
    final paymentStatus = data['paymentStatus']?.toString() ?? '';

    Color statusColor;
    String statusText;

    if (status == 'approved') {
      statusColor = Colors.green;
      statusText = t('مقبول', 'Approved');
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusText = t('مرفوض', 'Rejected');
    } else {
      statusColor = yaHalaGold;
      statusText = t('قيد المراجعة', 'Pending');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: imageUrl.isEmpty
                    ? Container(
                        width: 76,
                        height: 76,
                        color: isDark ? bgDark : Colors.white,
                        child: const Icon(Icons.image, color: Colors.grey),
                      )
                    : Image.network(
                        imageUrl,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) {
                          return Container(
                            width: 76,
                            height: 76,
                            color: isDark ? bgDark : Colors.white,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty
                          ? t('إعلان بدون عنوان', 'Untitled Ad')
                          : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _subtitle(category, city, placement),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _chip(statusText, statusColor),
                        if (paymentStatus == 'free_pilot')
                          _chip(t('مجاني حاليا', 'Free pilot'), yaHalaGreen),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status == 'rejected' && rejectionReason.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: isDark ? 0.18 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${t('سبب الرفض', 'Rejection reason')}: $rejectionReason',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: yaHalaGreen),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditAdScreen(
                          isArabic: isArabic,
                          isDark: isDark,
                          docId: docId,
                          data: data,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text(t('حذف الإعلان', 'Delete Ad')),
                        content: Text(
                          t(
                            'هل أنت متأكد أنك تريد حذف هذا الإعلان؟',
                            'Are you sure you want to delete this ad?',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: Text(t('إلغاء', 'Cancel')),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: Text(t('حذف', 'Delete')),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await FirebaseFirestore.instance
                          .collection('ads')
                          .doc(docId)
                          .delete();

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t('تم حذف الإعلان', 'Ad deleted')),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(String category, String city, String placement) {
    if (placement == vipAdPlacement) {
      return t('طلب إعلان VIP أعلى الصفحة', 'Top Page VIP Ad Request');
    }
    if (placement == featuredHomeAdPlacement) {
      return t('طلب إعلان مميز تحت VIP', 'Featured Ad Request');
    }
    if (placement == categoryTopAdPlacement) {
      return t('طلب أولوية أول 10 بالقسم', 'Top 10 Category Request');
    }
    return city.isEmpty ? category : '$category • $city';
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
