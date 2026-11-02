import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/exercise_library_service.dart';
import '../theme/app_colors.dart';

// Чипы групп мышц с цветными картинками (выбор упражнения, библиотека,
// диалог «Новое упражнение»). Невыбранные — полупрозрачные; подпись у
// выбранного (или у всех, если alwaysShowLabels).
// 'all' — «Все» первым чипом (includeAll).
class MuscleGroupChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final bool includeAll;
  // false — одна строка с горизонтальной прокруткой, true — перенос (Wrap)
  final bool wrap;
  final bool alwaysShowLabels;
  // Фон невыбранного чипа: surface на экране, surfaceInset в диалоге
  final Color unselectedColor;

  const MuscleGroupChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.includeAll = true,
    this.wrap = false,
    this.alwaysShowLabels = false,
    this.unselectedColor = AppColors.surface,
  });

  List<String> get _groups =>
      [if (includeAll) 'all', ...ExerciseLibraryService.validGroups];

  @override
  Widget build(BuildContext context) {
    if (wrap) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _groups.map(_buildChip).toList(),
      );
    }
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final key in _groups)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildChip(key),
            ),
        ],
      ),
    );
  }

  Widget _buildChip(String key) {
    final isSelected = selected == key;
    final label =
        key == 'all' ? 'workout.all_exercises'.tr() : 'workout.muscle_$key'.tr();
    final showLabel = isSelected || alwaysShowLabels;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onSelected(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 12 : 8,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.15)
                : unselectedColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              key == 'all'
                  ? Icon(
                      Icons.fitness_center,
                      color:
                          isSelected ? AppColors.accent : AppColors.textMuted,
                      size: 20,
                    )
                  // Картинка в своих цветах, как в списке упражнений;
                  // невыбранные — полупрозрачные
                  : Opacity(
                      opacity: isSelected ? 1.0 : 0.5,
                      child: Image.asset(
                        'assets/images/muscles/$key.png',
                        width: 22,
                        height: 22,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.fitness_center,
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ),
              if (showLabel) ...[
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.accent : AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Значок группы мышц в оранжевом квадрате 36×36 (строки списков упражнений).
// Без группы — гантель.
class MuscleGroupIcon extends StatelessWidget {
  final String group;

  const MuscleGroupIcon({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: group.isNotEmpty
          ? Image.asset(
              'assets/images/muscles/$group.png',
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center,
                  color: AppColors.accent, size: 18),
            )
          : const Icon(Icons.fitness_center,
              color: AppColors.accent, size: 18),
    );
  }
}
