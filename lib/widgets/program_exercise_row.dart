import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/program_models.dart';
import '../theme/app_colors.dart';
import 'exercise_display.dart';
import 'exercise_info_button.dart';

// План упражнения программы: «4 × 8–12», «3 × 10» (от = до) или «4 подх.» без плана повторов.
String programExercisePlanText(ProgramExercise ex) => ex.repsRangeText != null
    ? '${ex.targetSets} × ${ex.repsRangeText}'
    : '${ex.targetSets} ${'programs.sets_short'.tr()}';

// Одна строка упражнения дня программы (только просмотр): название, мышца, ⓘ, план.
// Используется в раскрытой карточке дня (Program details) и в просмотре готовой программы.
class ProgramExerciseRow extends StatelessWidget {
  final ProgramExercise exercise;

  const ProgramExerciseRow({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    // В шаблоне хранится ключ мышцы (chest) — показываем перевод
    final muscle = programExerciseMuscleLabel(context, exercise);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  programExerciseDisplayName(context, exercise),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                if (muscle.isNotEmpty)
                  Text(
                    muscle,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          // Демо упражнения; нажатие не сворачивает карточку дня
          ExerciseInfoButton(
              templateId: exercise.templateId, name: exercise.name),
          const SizedBox(width: 8),
          Text(
            programExercisePlanText(exercise),
            style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
