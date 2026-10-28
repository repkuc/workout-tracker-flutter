import 'package:flutter/widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/program_models.dart';
import '../models/workout_models.dart';
import '../services/exercise_catalog_service.dart';
import '../services/exercise_library_service.dart';

// Как показывать упражнение на экране. Сохранённые name / targetMuscle —
// «снимки», напрямую их не показываем: встроенное упражнение — на текущем
// языке, своё — под текущим названием из библиотеки, без id — как сохранено.
// context.locale подписывает виджет на смену языка, поэтому экран
// перестраивается сразу. Поиск синхронный — по каталогу в памяти.

// Название упражнения тренировки
String exerciseDisplayName(BuildContext context, Exercise exercise) =>
    ExerciseCatalogService().displayName(
      templateId: exercise.templateId,
      name: exercise.name,
      languageCode: context.locale.languageCode,
    );

// Название упражнения дня программы
String programExerciseDisplayName(
        BuildContext context, ProgramExercise exercise) =>
    ExerciseCatalogService().displayName(
      templateId: exercise.templateId,
      name: exercise.name,
      languageCode: context.locale.languageCode,
    );

// Группа мышц упражнения тренировки: перевод ключа muscleGroup,
// без ключа — сохранённый текст targetMuscle ('' — нет группы).
String exerciseMuscleLabel(BuildContext context, Exercise exercise) {
  context.locale; // подписка на смену языка
  final group = exercise.muscleGroup;
  if (group != null && ExerciseLibraryService.validGroups.contains(group)) {
    return 'workout.muscle_$group'.tr();
  }
  return exercise.targetMuscle;
}

// Группа мышц упражнения программы: там targetMuscle — ключ ('chest');
// не ключ (старые данные) — показываем как есть.
String programExerciseMuscleLabel(
    BuildContext context, ProgramExercise exercise) {
  context.locale; // подписка на смену языка
  final group = exercise.targetMuscle;
  if (ExerciseLibraryService.validGroups.contains(group)) {
    return 'workout.muscle_$group'.tr();
  }
  return group;
}
