import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/workout_models.dart';
import '../theme/app_colors.dart';

// Текст цели упражнения из программы: «4 × 8–12», «4 × 10» (от = до)
// или «4 подх.», если плана повторов нет. null — у упражнения нет плана.
String? exerciseGoalText(Exercise exercise) {
  final sets = exercise.plannedSets;
  if (sets == null) return null;
  final min = exercise.plannedRepsMin;
  final max = exercise.plannedRepsMax;
  if (min == null || max == null) {
    return '$sets ${'programs.sets_short'.tr()}';
  }
  return min == max ? '$sets × $min' : '$sets × $min–$max';
}

// Строка цели: «🎯 4 × 8–12» и счётчик «2 / 4» (выполненные подходы / план).
// Когда выполнено не меньше плана — счётчик зелёный с ✓.
// Для упражнений без плана ничего не рисует.
class ExerciseGoalLine extends StatelessWidget {
  final Exercise exercise;

  const ExerciseGoalLine({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final goal = exerciseGoalText(exercise);
    if (goal == null) return const SizedBox.shrink();

    final planned = exercise.plannedSets!;
    final done = exercise.doneSetsCount;
    final reached = done >= planned;
    final counterColor = reached ? AppColors.success : AppColors.inactive;

    return Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Semantics(
          label: 'workout.goal'.tr(),
          child: Text(
            '🎯 $goal',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Semantics(
          label: 'workout.sets_done'.tr(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: counterColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              reached ? '✓ $done / $planned' : '$done / $planned',
              style: TextStyle(
                color: counterColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
