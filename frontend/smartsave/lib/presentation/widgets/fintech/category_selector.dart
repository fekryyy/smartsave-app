import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CategorySelector extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onChanged;
  final Map<String, IconData> icons;
  final Map<String, Color> categoryColors;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selected,
    required this.onChanged,
    required this.icons,
    required this.categoryColors,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: categories.map((cat) {
        final col = categoryColors[cat] ?? AppColors.primary;
        final isSelected = selected == cat;
        return GestureDetector(
          onTap: () => onChanged(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? col.withOpacity(0.12) : (isDark ? AppColors.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? col.withOpacity(0.4) : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            transformAlignment: Alignment.center,
            transform: isSelected ? Matrix4.diagonal3Values(1.03, 1.03, 1) : Matrix4.identity(),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icons[cat] ?? Icons.category, size: 18, color: isSelected ? col : (isDark ? AppColors.grey400 : const Color(0xFF64748B))),
              const SizedBox(width: 8),
              Text(cat, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? col : (isDark ? AppColors.grey400 : const Color(0xFF475569)))),
            ]),
          ),
        );
      }).toList(),
    );
  }
}
