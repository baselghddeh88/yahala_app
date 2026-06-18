import 'package:flutter/material.dart';

const green = Color(0xFF1A6B3C);
const gold = Color(0xFFC9952A);
const dark = Color(0xFF1A1A1A);
const bg = Color(0xFFF7F7F7);

const yahalaGreen = Color(0xFF1A6B3C);
const yahalaGold = Color(0xFFC9952A);
const yahalaInk = Color(0xFF121826);
const yahalaDarkBg = Color(0xFF0E1621);
const yahalaDarkCard = Color(0xFF182635);
const yahalaLightBg = Color(0xFFF7F8F6);
const yahalaLightCard = Colors.white;
const yahalaLogoAsset = 'assets/logo.PNG';

Color yahalaPageBg(bool isDark) => isDark ? yahalaDarkBg : yahalaLightBg;

Color yahalaCardBg(bool isDark) => isDark ? yahalaDarkCard : yahalaLightCard;

Color yahalaText(bool isDark) => isDark ? Colors.white : yahalaInk;

Color yahalaMutedText(bool isDark) =>
    isDark ? Colors.white70 : const Color(0xFF687076);

Widget yahalaLogo({double width = 140}) {
  return Image.asset(
    yahalaLogoAsset,
    width: width,
    errorBuilder: (context, error, stackTrace) {
      return SizedBox(
        width: width,
        height: width,
        child: const Center(
          child: Text(
            'يا هلا',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: yahalaGold,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    },
  );
}
