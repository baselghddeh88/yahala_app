import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ad_details_screen.dart';
import 'question_details_screen.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

class FavoritesScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;

  const FavoritesScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String selectedCategory = '';

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: widget.isDark ? bgDark : Colors.white,
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          centerTitle: true,
          title: Text(
            t('المفضلة', 'Favorites'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: user == null
            ? Center(
                child: Text(
                  t('سجّل الدخول لعرض المفضلة', 'Login to view favorites'),
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                  ),
                ),
              )
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('favorites')
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

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final favorites = snapshot.data!.docs;

                  if (favorites.isEmpty) {
                    return Center(
                      child: Text(
                        t('لا توجد عناصر في المفضلة بعد', 'No favorites yet'),
                        style: TextStyle(
                          color: widget.isDark ? Colors.white : Colors.black,
                          fontSize: 18,
                        ),
                      ),
                    );
                  }

                  final categories = _categoriesFrom(favorites);
                  final filtered = selectedCategory.isEmpty
                      ? favorites
                      : favorites.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['category']?.toString() ==
                              selectedCategory;
                        }).toList();

                  return Column(
                    children: [
                      _categoryTabs(categories),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(18),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final doc = filtered[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return _favoriteCard(context, doc.id, data);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  List<String> _categoriesFrom(List<QueryDocumentSnapshot> favorites) {
    final categories = <String>{};

    for (final doc in favorites) {
      final data = doc.data() as Map<String, dynamic>;
      final category = data['category']?.toString() ?? '';
      if (category.isNotEmpty) categories.add(category);
    }

    return categories.toList()..sort();
  }

  Widget _categoryTabs(List<String> categories) {
    return SizedBox(
      height: 58,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
        scrollDirection: Axis.horizontal,
        children: [
          _categoryChip(t('الكل', 'All'), ''),
          ...categories.map((category) => _categoryChip(category, category)),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, String value) {
    final selected = selectedCategory == value;

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: yaHalaGreen,
        labelStyle: TextStyle(
          color: selected
              ? Colors.white
              : (widget.isDark ? Colors.white : Colors.black),
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
        onSelected: (_) => setState(() => selectedCategory = value),
      ),
    );
  }

  Widget _favoriteCard(
    BuildContext context,
    String favoriteId,
    Map<String, dynamic> data,
  ) {
    final adId = data['adId']?.toString() ?? favoriteId;
    final title = data['title']?.toString() ?? '';
    final city = data['city']?.toString() ?? '';
    final category = data['category']?.toString() ?? '';
    final imageUrl = data['imageUrl']?.toString() ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => category == 'سؤال'
                ? QuestionDetailsScreen(
                    isArabic: widget.isArabic,
                    isDark: widget.isDark,
                    questionId: adId,
                    data: data,
                  )
                : AdDetailsScreen(
                    isArabic: widget.isArabic,
                    isDark: widget.isDark,
                    data: data,
                    adId: adId,
                  ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isDark ? cardColor : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isEmpty
                  ? Container(
                      width: 70,
                      height: 70,
                      color: widget.isDark ? bgDark : Colors.white,
                      child: const Icon(Icons.image, color: Colors.grey),
                    )
                  : Image.network(
                      imageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
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
                      color: widget.isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    city.isEmpty ? category : '$category • $city',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('favorites')
                    .doc(favoriteId)
                    .delete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
