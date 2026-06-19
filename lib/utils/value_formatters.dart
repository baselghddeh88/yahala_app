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
