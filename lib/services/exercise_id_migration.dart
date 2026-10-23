import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise_template.dart';
import 'exercise_catalog_service.dart';
import 'exercise_library_service.dart';
import 'program_service.dart';
import 'workout_service.dart';

// Разовая миграция: привязать упражнения в тренировках и программах к id шаблона.
// Заполняет только пустые поля, поэтому повторный запуск ничего не меняет.
// При старте выполняется один раз (флаг), после импорта бэкапа — всегда.
class ExerciseIdMigration {
  static const String flagKey = 'wt.exercise_ids_migrated.v1';
  static const String summaryKey = 'wt.exercise_ids_migration_summary.v1';
  // Сырые копии данных до первой миграции — чтобы можно было восстановить вручную
  static const String preWorkoutsKey = 'wt.workouts.pre_id_migration.v1';
  static const String preProgramsKey = 'wt.programs.pre_id_migration.v1';
  static const String preCustomKey = 'wt.custom_exercises.pre_id_migration.v1';

  static final ExerciseIdMigration _instance = ExerciseIdMigration._internal();
  factory ExerciseIdMigration() => _instance;
  ExerciseIdMigration._internal();

  // Запустить миграцию. force — не смотреть на флаг (после импорта).
  // Возвращает сводку или null, если миграция уже была.
  Future<Map<String, int>?> run({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool(flagKey) ?? false)) return null;

    await _savePreMigrationCopy(prefs);

    final catalog = ExerciseCatalogService();
    final library = ExerciseLibraryService();
    final workoutService = WorkoutService();
    final programService = ProgramService();
    await catalog.reload();

    final builtIn = await library.getBuiltInExercises();
    final custom = await library.getCustomExercises();
    final builtInIds = builtIn.map((e) => e.id).toSet();
    final muscleByLabel = await _loadMuscleLabels();

    // Название → id: каталог (встроенные важнее) + созданные по ходу
    final createdByName = <String, ExerciseTemplate>{};
    final templates = {for (final t in [...builtIn, ...custom]) t.id: t};

    int matchedBuiltIn = 0, matchedCustom = 0, createdCustom = 0;
    int exerciseMuscleFilled = 0, customMuscleFilled = 0;
    bool customChanged = false;
    final createdAt = DateTime.now().millisecondsSinceEpoch;

    // id для названия: встроенное → пользовательское → новое пользовательское
    String? resolve(String name) {
      final key = ExerciseCatalogService.normalize(name);
      if (key.isEmpty) return null;
      final id = catalog.idForName(name) ?? createdByName[key]?.id;
      if (id != null) {
        if (builtInIds.contains(id)) {
          matchedBuiltIn++;
        } else {
          matchedCustom++;
        }
        return id;
      }
      final created = ExerciseTemplate(
        id: 'custom_${createdAt}_${createdByName.length}',
        nameRu: name.trim(),
        nameLv: name.trim(),
        nameEn: name.trim(),
        isCustom: true,
      );
      createdByName[key] = created;
      templates[created.id] = created;
      custom.add(created);
      customChanged = true;
      createdCustom++;
      return created.id;
    }

    // Ключ группы мышц по переведённому тексту (любой из трёх языков)
    String? muscleFromText(String text) =>
        muscleByLabel[ExerciseCatalogService.normalize(text)];

    // --- Тренировки ---
    final workouts = await workoutService.loadAllWorkouts();
    bool workoutsChanged = false;
    for (final workout in workouts) {
      for (final exercise in workout.exercises) {
        if (exercise.templateId == null) {
          final id = resolve(exercise.name);
          if (id != null) {
            exercise.templateId = id;
            workoutsChanged = true;
          }
        }
        if (exercise.muscleGroup == null) {
          final fromTemplate = templates[exercise.templateId]?.muscleGroup ?? '';
          final key = fromTemplate.isNotEmpty
              ? fromTemplate
              : muscleFromText(exercise.targetMuscle);
          if (key != null) {
            exercise.muscleGroup = key;
            exerciseMuscleFilled++;
            workoutsChanged = true;
          }
        }
      }
    }

    // --- Программы ---
    final programs = await programService.loadAllPrograms();
    bool programsChanged = false;
    for (final program in programs) {
      for (final day in program.workouts) {
        for (final exercise in day.exercises) {
          if (exercise.templateId != null) continue;
          final id = resolve(exercise.name);
          if (id != null) {
            exercise.templateId = id;
            programsChanged = true;
          }
        }
      }
    }

    // --- Группа мышц у пользовательских упражнений без группы ---
    // Берём самую частую группу среди тренировок с этим упражнением,
    // только если она одна (без ничьей).
    final votes = <String, Map<String, int>>{};
    for (final workout in workouts) {
      for (final exercise in workout.exercises) {
        final template = templates[exercise.templateId];
        if (template == null || !template.isCustom) continue;
        if (template.muscleGroup.isNotEmpty) continue;
        final key = exercise.muscleGroup;
        if (key == null) continue;
        final counts = votes.putIfAbsent(template.id, () => {});
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    for (var i = 0; i < custom.length; i++) {
      final template = custom[i];
      final counts = votes[template.id];
      if (counts == null || template.muscleGroup.isNotEmpty) continue;
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.length > 1 && sorted[0].value == sorted[1].value) continue;
      final filled = ExerciseTemplate(
        id: template.id,
        nameRu: template.nameRu,
        nameLv: template.nameLv,
        nameEn: template.nameEn,
        muscleGroup: sorted[0].key,
        isCustom: template.isCustom,
      );
      custom[i] = filled;
      templates[filled.id] = filled;
      customMuscleFilled++;
      customChanged = true;
    }
    // Теперь у части шаблонов есть группа — дозаполняем упражнения
    for (final workout in workouts) {
      for (final exercise in workout.exercises) {
        if (exercise.muscleGroup != null) continue;
        final key = templates[exercise.templateId]?.muscleGroup ?? '';
        if (key.isEmpty) continue;
        exercise.muscleGroup = key;
        exerciseMuscleFilled++;
        workoutsChanged = true;
      }
    }

    // Сохраняем: сначала библиотеку (на неё ссылаются), потом данные, флаг — последним
    if (customChanged) await library.saveCustomExercises(custom);
    if (workoutsChanged) await workoutService.saveAllWorkouts(workouts);
    if (programsChanged) await programService.saveAllPrograms(programs);
    await catalog.reload();

    final summary = {
      'matchedBuiltIn': matchedBuiltIn,
      'matchedCustom': matchedCustom,
      'createdCustom': createdCustom,
      'exerciseMuscleFilled': exerciseMuscleFilled,
      'customMuscleFilled': customMuscleFilled,
      'duplicatesHidden': custom.where(catalog.isBuiltInDuplicate).length,
    };
    await prefs.setString(summaryKey, json.encode(summary));
    await prefs.setBool(flagKey, true);
    debugPrint('Exercise id migration${force ? ' (forced)' : ''}: $summary');
    return summary;
  }

  // Один раз сохранить сырые строки тренировок, программ и своих упражнений
  Future<void> _savePreMigrationCopy(SharedPreferences prefs) async {
    if (prefs.containsKey(preWorkoutsKey)) return;
    await prefs.setString(
        preCustomKey, prefs.getString('wt.custom_exercises.v1') ?? '');
    await prefs.setString(preProgramsKey, prefs.getString('wt.programs.v1') ?? '');
    // Ключ тренировок — последним: по нему проверяем, что копия уже есть
    await prefs.setString(preWorkoutsKey, prefs.getString('wt.workouts.v1') ?? '');
  }

  // Подписи групп мышц из всех трёх файлов переводов → ключ группы
  Future<Map<String, String>> _loadMuscleLabels() async {
    final result = <String, String>{};
    for (final lang in ['ru', 'lv', 'en']) {
      try {
        final data = json.decode(
            await rootBundle.loadString('assets/translations/$lang.json'));
        final section = data['workout'] as Map<String, dynamic>;
        for (final group in ExerciseLibraryService.validGroups) {
          final label = section['muscle_$group'];
          if (label is String) {
            result[ExerciseCatalogService.normalize(label)] = group;
          }
        }
      } catch (_) {
        // Без подписей группа просто не заполнится по тексту
      }
    }
    return result;
  }
}
