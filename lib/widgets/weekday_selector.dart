import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_colors.dart';

// Короткое название дня недели: 1 = Пн … 7 = Вс (ключи programs.weekday_short_N).
String weekdayShortName(int day) => 'programs.weekday_short_$day'.tr();

// Дни программы одной строкой: «Пн · Ср · Пт»; все 7 — «Каждый день»; пусто — ''.
String formatScheduleDays(List<int> days) {
  if (days.isEmpty) return '';
  if (days.toSet().length == 7) return 'programs.every_day'.tr();
  final sorted = days.toSet().toList()..sort();
  return sorted.map(weekdayShortName).join(' · ');
}

// 7 переключателей дней недели (Пн … Вс) для расписания программы.
// Если все 7 помещаются в строку — делят ширину поровну,
// на узком экране (например внутри диалога) переносятся на вторую строку.
// unselectedColor — фон невыбранного дня: inputFill в диалоге, inputFillOnPage на странице.
class WeekdaySelector extends StatelessWidget {
  final List<int> selectedDays;
  final ValueChanged<List<int>> onChanged;
  final Color unselectedColor;

  const WeekdaySelector({
    super.key,
    required this.selectedDays,
    required this.onChanged,
    this.unselectedColor = AppColors.inputFill,
  });

  static const double _gap = 6;
  static const double _minChipWidth = 36;
  static const double _wrapChipWidth = 44;

  void _toggle(int day) {
    final days = selectedDays.toSet();
    if (!days.remove(day)) days.add(day);
    onChanged(days.toList()..sort());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final oneLineWidth =
            ((constraints.maxWidth - _gap * 6) / 7).floorToDouble();
        final chipWidth =
            oneLineWidth >= _minChipWidth ? oneLineWidth : _wrapChipWidth;

        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: List.generate(7, (i) {
            final day = i + 1;
            final selected = selectedDays.contains(day);
            return Semantics(
              button: true,
              selected: selected,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggle(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: chipWidth,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : unselectedColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.chipBorder,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        weekdayShortName(day),
                        style: TextStyle(
                          color: selected ? Colors.white : AppColors.inactive,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
