import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/ad_actions.dart';

class FavoriteButton extends StatelessWidget {
  final String adId;
  final Map<String, dynamic> data;
  final bool isArabic;
  final Color savedColor;
  final Color unsavedColor;
  final double iconSize;

  const FavoriteButton({
    super.key,
    required this.adId,
    required this.data,
    required this.isArabic,
    this.savedColor = Colors.redAccent,
    this.unsavedColor = Colors.redAccent,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || adId.isEmpty) {
      return IconButton(
        onPressed: () => AdActions.toggleFavorite(
          context,
          adId: adId,
          data: data,
          isArabic: isArabic,
        ),
        icon: Icon(Icons.favorite_border, color: unsavedColor, size: iconSize),
      );
    }

    final favoriteRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(adId);

    return StreamBuilder<DocumentSnapshot>(
      stream: favoriteRef.snapshots(),
      builder: (context, snapshot) {
        final isSaved = snapshot.data?.exists ?? false;

        return IconButton(
          onPressed: () => AdActions.toggleFavorite(
            context,
            adId: adId,
            data: data,
            isArabic: isArabic,
          ),
          icon: Icon(
            isSaved ? Icons.favorite : Icons.favorite_border,
            color: isSaved ? savedColor : unsavedColor,
            size: iconSize,
          ),
        );
      },
    );
  }
}
