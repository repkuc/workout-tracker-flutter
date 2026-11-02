import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/exercise_template.dart';
import '../services/custom_exercise_service.dart';
import '../services/exercise_catalog_service.dart';
import '../theme/app_colors.dart';
import 'app_dialog.dart';
import 'muscle_group_chips.dart';

// Что делать, если введённое название уже есть в библиотеке
// (встроенное на любом языке, своё, скрытый дубликат встроенного):
// error — ошибка под полем (библиотека упражнений);
// useExisting — закрыть диалог и взять существующее (выбор упражнения).
enum NewExerciseOnExisting { error, useExisting }

// Результат диалога: созданное упражнение или существующее (existed).
class NewExerciseResult {
  final ExerciseTemplate template;
  final bool existed;

  const NewExerciseResult(this.template, {this.existed = false});
}

// Диалог «Новое упражнение» (библиотека упражнений и выбор упражнения):
// название и группа мышц (необязательная). Пустое название — ошибка под
// полем; занятое — см. onExisting. Создаёт упражнение через
// CustomExerciseService; null — отмена. Существующее никогда не дублируется.
Future<NewExerciseResult?> showNewExerciseDialog(
  BuildContext context, {
  NewExerciseOnExisting onExisting = NewExerciseOnExisting.error,
}) async {
  final service = CustomExerciseService();
  final nameController = TextEditingController();
  String group = '';
  String? nameError;

  // null — отмена, '' — создать новое, иначе id существующего упражнения
  final choice = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AppDialog(
        icon: Icons.fitness_center,
        title: 'exercise_library.new_exercise'.tr(),
        // Фиксированная ширина — чипы переносятся по ширине диалога
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Без autofocus: клавиатура открывается по нажатию на поле
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                // Начали печатать — убираем ошибку
                onChanged: (_) {
                  if (nameError != null) {
                    setDialogState(() => nameError = null);
                  }
                },
                decoration: appDialogInputDecoration(
                  labelText: 'workout.exercise_name'.tr(),
                  hintText: 'workout.exercise_name_hint'.tr(),
                  icon: Icons.fitness_center,
                  errorText: nameError,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'exercise_library.muscle_group'.tr(),
                style: const TextStyle(color: AppColors.accent, fontSize: 12),
              ),
              const SizedBox(height: 8),
              // Повторное нажатие на выбранную группу снимает выбор
              MuscleGroupChips(
                selected: group,
                includeAll: false,
                wrap: true,
                alwaysShowLabels: true,
                unselectedColor: AppColors.surfaceInset,
                onSelected: (key) =>
                    setDialogState(() => group = group == key ? '' : key),
              ),
            ],
          ),
        ),
        actions: [
          AppDialogCancelButton(
            label: 'workout.cancel'.tr(),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          AppDialogConfirmButton(
            label: 'exercise_library.create'.tr(),
            onPressed: () {
              final conflict = service.createConflict(nameController.text);
              if (conflict == 'empty') {
                setDialogState(() =>
                    nameError = 'workout.exercise_name_required'.tr());
                return;
              }
              if (conflict != null) {
                if (onExisting == NewExerciseOnExisting.useExisting) {
                  Navigator.pop(dialogContext, conflict);
                } else {
                  setDialogState(() =>
                      nameError = 'exercise_library.already_exists'.tr());
                }
                return;
              }
              Navigator.pop(dialogContext, '');
            },
          ),
        ],
      ),
    ),
  );

  if (choice == null) return null;
  if (choice.isNotEmpty) {
    final existing = ExerciseCatalogService().templateById(choice);
    return existing == null
        ? null
        : NewExerciseResult(existing, existed: true);
  }
  return NewExerciseResult(
      await service.create(name: nameController.text, muscleGroup: group));
}
