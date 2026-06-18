import 'package:flutter/material.dart';

import '../data/california_cities.dart';

class CityPickerField extends StatelessWidget {
  final TextEditingController controller;
  final bool isArabic;
  final bool isDark;
  final String hint;
  final EdgeInsetsGeometry? margin;
  final ValueChanged<String>? onSelected;

  const CityPickerField({
    super.key,
    required this.controller,
    required this.isArabic,
    required this.isDark,
    required this.hint,
    this.margin,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _openPicker(context),
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.location_city, color: Colors.grey),
        suffixIcon: controller.text.isEmpty
            ? const Icon(Icons.keyboard_arrow_down, color: Colors.grey)
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onSelected?.call('');
                },
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1c2b3a) : const Color(0xFFF3F3F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );

    if (margin == null) return field;

    return Container(margin: margin, child: field);
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1c2b3a) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return _CityPickerSheet(
          isArabic: isArabic,
          isDark: isDark,
          selectedCity: controller.text,
        );
      },
    );

    if (selected == null) return;

    controller.text = selected;
    onSelected?.call(selected);
  }
}

class _CityPickerSheet extends StatefulWidget {
  final bool isArabic;
  final bool isDark;
  final String selectedCity;

  const _CityPickerSheet({
    required this.isArabic,
    required this.isDark,
    required this.selectedCity,
  });

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final searchController = TextEditingController();

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final cities = query.isEmpty
        ? californiaCities
        : californiaCities
              .where((city) => city.toLowerCase().contains(query))
              .toList();

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 14,
              ),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('اختر المدينة', 'Choose city'),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: t('ابحث عن مدينة...', 'Search city...'),
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: widget.isDark
                          ? const Color(0xFF0e1621)
                          : const Color(0xFFF3F3F3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: cities.length,
                      itemBuilder: (context, index) {
                        final city = cities[index];
                        final selected = city == widget.selectedCity;

                        return ListTile(
                          title: Text(
                            city,
                            style: TextStyle(
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black,
                              fontWeight: selected
                                  ? FontWeight.w900
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF1a6b3c),
                                )
                              : null,
                          onTap: () => Navigator.pop(context, city),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
