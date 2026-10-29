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

// Дни программы маленькими чипами только для просмотра (готовые программы).
// Все 7 — один чип «Каждый день»; пусто — ничего.
class ScheduleDayChips extends StatelessWidget {
  final List<int> days;

  const ScheduleDayChips({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    context.locale; // подписка на смену языка
    final sorted = days.toSet().toList()..sort();
    if (sorted.isEmpty) return const SizedBox.shrink();
    final labels = sorted.length == 7
        ? ['programs.every_day'.tr()]
        : sorted.map(weekdayShortName).toList();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: labels
          .map((label) => Container(
                constraints: const BoxConstraints(minWidth: 28),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ))
          .toList(),
    );
  }
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
