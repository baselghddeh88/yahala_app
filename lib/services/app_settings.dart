import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const _languageChosenKey = 'language_chosen';
  static const _isArabicKey = 'is_arabic';
  static const _isDarkKey = 'is_dark';
  static const _legalAcceptedKey = 'legal_accepted';
  static const legalVersion = '2026-06-18';

  final bool languageChosen;
  final bool isArabic;
  final bool isDark;

  const AppSettings({
    required this.languageChosen,
    required this.isArabic,
    required this.isDark,
  });

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    return AppSettings(
      languageChosen: prefs.getBool(_languageChosenKey) ?? false,
      isArabic: prefs.getBool(_isArabicKey) ?? true,
      isDark: prefs.getBool(_isDarkKey) ?? false,
    );
  }

  static Future<void> save({
    required bool isArabic,
    required bool isDark,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_languageChosenKey, true);
    await prefs.setBool(_isArabicKey, isArabic);
    await prefs.setBool(_isDarkKey, isDark);
  }

  static Future<bool> hasAcceptedLegal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_legalAcceptedKey) ?? false;
  }

  static Future<void> saveLegalAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_legalAcceptedKey, true);
  }
}
