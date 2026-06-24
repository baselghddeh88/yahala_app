import 'package:flutter/material.dart';

import 'city_picker_field.dart';

const Color _yaHalaGreen = Color(0xFF1a6b3c);
const Color _bgDark = Color(0xFF0e1621);
const Color _cardColor = Color(0xFF1c2b3a);

class SectionFilterPanel extends StatefulWidget {
  final bool isArabic;
  final bool isDark;
  final String title;
  final String searchHint;
  final TextEditingController searchController;
  final TextEditingController cityController;
  final TextEditingController zipController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCitySelected;
  final ValueChanged<String> onZipChanged;
  final VoidCallback onClear;
  final bool hasActiveFilters;
  final Widget? extraFilter;

  const SectionFilterPanel({
    super.key,
    required this.isArabic,
    required this.isDark,
    required this.title,
    required this.searchHint,
    required this.searchController,
    required this.cityController,
    required this.zipController,
    required this.onSearchChanged,
    required this.onCitySelected,
    required this.onZipChanged,
    required this.onClear,
    required this.hasActiveFilters,
    this.extraFilter,
  });

  @override
  State<SectionFilterPanel> createState() => _SectionFilterPanelState();
}

class _SectionFilterPanelState extends State<SectionFilterPanel> {
  bool showAdvanced = false;

  @override
  void didUpdateWidget(covariant SectionFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasActiveFilters && !oldWidget.hasActiveFilters) {
      showAdvanced = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black;
    final muted = widget.isDark ? Colors.white60 : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? _cardColor : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (widget.hasActiveFilters)
                TextButton.icon(
                  onPressed: widget.onClear,
                  style: TextButton.styleFrom(
                    foregroundColor: _yaHalaGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(widget.isArabic ? 'مسح' : 'Clear'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _filterInput(
            controller: widget.searchController,
            hint: widget.searchHint,
            icon: Icons.search,
            onChanged: widget.onSearchChanged,
          ),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => showAdvanced = !showAdvanced),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.tune, color: _yaHalaGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isArabic ? 'فلاتر إضافية' : 'More filters',
                      style: TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: showAdvanced ? 0.5 : 0,
                    child: Icon(Icons.keyboard_arrow_down, color: muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  if (widget.extraFilter != null) ...[
                    widget.extraFilter!,
                    const SizedBox(height: 10),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final city = CityPickerField(
                        controller: widget.cityController,
                        isArabic: widget.isArabic,
                        isDark: widget.isDark,
                        hint: widget.isArabic ? 'المدينة' : 'City',
                        onSelected: widget.onCitySelected,
                      );
                      final zip = _filterInput(
                        controller: widget.zipController,
                        hint: 'ZIP',
                        icon: Icons.pin_drop,
                        keyboardType: TextInputType.number,
                        onChanged: widget.onZipChanged,
                      );

                      if (constraints.maxWidth < 390) {
                        return Column(children: [city, zip]);
                      }

                      return Row(
                        children: [
                          Expanded(child: city),
                          const SizedBox(width: 10),
                          Expanded(child: zip),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            crossFadeState: showAdvanced
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Widget _filterInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: _yaHalaGreen),
          filled: true,
          fillColor: widget.isDark ? _bgDark : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
