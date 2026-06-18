import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/app_settings.dart';
import 'auth_choice_screen.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  bool isArabic = true;
  bool darkMode = false;

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: yahalaPageBg(darkMode),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: yahalaCardBg(darkMode),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: darkMode ? 0.25 : 0.08,
                              ),
                              blurRadius: 30,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: yahalaLogo(width: 128),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        t('يا هلا', 'Yahala'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: yahalaText(darkMode),
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        t('جريدة العرب في المهجر', 'Arab newspaper abroad'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: yahalaMutedText(darkMode),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _languageSelector(),
                      const SizedBox(height: 14),
                      _themeSelector(),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: yahalaGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () async {
                      await AppSettings.save(
                        isArabic: isArabic,
                        isDark: darkMode,
                      );

                      if (!context.mounted) return;

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AuthChoiceScreen(
                            isArabic: isArabic,
                            isDark: darkMode,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      t('متابعة', 'Continue'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _languageSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: yahalaCardBg(darkMode),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: darkMode ? Colors.white10 : const Color(0xFFE6E8E2),
        ),
      ),
      child: Row(
        children: [
          _choicePill(
            label: 'العربية',
            selected: isArabic,
            onTap: () => setState(() => isArabic = true),
          ),
          const SizedBox(width: 8),
          _choicePill(
            label: 'English',
            selected: !isArabic,
            onTap: () => setState(() => isArabic = false),
          ),
        ],
      ),
    );
  }

  Widget _themeSelector() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => darkMode = !darkMode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: yahalaCardBg(darkMode),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: darkMode ? Colors.white10 : const Color(0xFFE6E8E2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              darkMode ? Icons.dark_mode : Icons.light_mode,
              color: yahalaGold,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                darkMode
                    ? t('الوضع الداكن', 'Dark mode')
                    : t('الوضع الفاتح', 'Light mode'),
                style: TextStyle(
                  color: yahalaText(darkMode),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Switch(
              value: darkMode,
              activeThumbColor: yahalaGold,
              onChanged: (value) => setState(() => darkMode = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choicePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? yahalaGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : yahalaText(darkMode),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
