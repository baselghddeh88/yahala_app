import 'package:flutter/services.dart';

bool containsLatinOrDigits(String value) {
  return RegExp(r'[A-Za-z0-9]').hasMatch(value);
}

String isolateLeftToRight(String value) {
  if (!containsLatinOrDigits(value)) return value;
  return '\u200E$value\u200E';
}

String cleanMoneyInput(String value) {
  return value.trim().replaceAll(RegExp(r'[\$٪%,]'), '').trim();
}

String cleanPercentInput(String value) {
  return value.trim().replaceAll(RegExp(r'[\$٪%,]'), '').trim();
}

String formatMoney(String value) {
  final clean = cleanMoneyInput(value);
  if (clean.isEmpty) return '';
  if (RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(clean)) return clean;
  return '\$${formatNumberWithCommas(clean)}';
}

String formatPercent(String value) {
  final clean = cleanPercentInput(value);
  if (clean.isEmpty) return '';
  if (RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(clean)) return clean;
  return '${formatNumberWithCommas(clean)}%';
}

String formatCouponValue(String value, String type) {
  if (type == 'percent') return formatPercent(value);
  if (type == 'amount') return formatMoney(value);
  return value.trim();
}

String formatNumberWithCommas(String value) {
  final normalized = value.trim().replaceAll(',', '');
  if (normalized.isEmpty) return '';

  final parts = normalized.split('.');
  final whole = parts.first;
  final decimal = parts.length > 1 ? parts.sublist(1).join('.') : '';

  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  if (decimal.isEmpty) return buffer.toString();
  return '${buffer.toString()}.$decimal';
}

String cleanPhoneInput(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String formatPhoneNumber(String value) {
  final digits = cleanPhoneInput(value);
  if (digits.isEmpty) return '';

  final local = digits.length == 11 && digits.startsWith('1')
      ? digits.substring(1)
      : digits;

  if (local.length <= 3) return local;
  if (local.length <= 6) {
    return '(${local.substring(0, 3)}) ${local.substring(3)}';
  }

  final limited = local.length > 10 ? local.substring(0, 10) : local;
  return '(${limited.substring(0, 3)}) ${limited.substring(3, 6)}-${limited.substring(6)}';
}

class PhoneNumberInputFormatter extends TextInputFormatter {
  const PhoneNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatPhoneNumber(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
