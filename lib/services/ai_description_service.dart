import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

class AiDescriptionService {
  static final Uri _endpoint = Uri.parse(
    'https://us-central1-yahala-9b386.cloudfunctions.net/formatAdDescription',
  );

  static Future<String> formatDescription({
    required String title,
    required String description,
    required String category,
    required bool isArabic,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AiDescriptionException('login-required');
    }

    final token = await user.getIdToken();
    final client = HttpClient();

    try {
      final request = await client.postUrl(_endpoint);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(
        jsonEncode({
          'title': title.trim(),
          'description': description.trim(),
          'category': category.trim(),
          'isArabic': isArabic,
        }),
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw AiDescriptionException(data['error']?.toString() ?? 'failed');
      }

      final formatted = data['description']?.toString().trim() ?? '';
      if (formatted.isEmpty) throw const AiDescriptionException('empty');

      return formatted;
    } finally {
      client.close(force: true);
    }
  }
}

class AiDescriptionException implements Exception {
  final String code;

  const AiDescriptionException(this.code);

  @override
  String toString() => code;
}
