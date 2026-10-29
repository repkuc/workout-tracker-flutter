import 'package:easy_localization/easy_localization.dart';
import '../models/exercise_template.dart';
import '../models/program_models.dart';
import '../models/workout_models.dart';
import 'exercise_catalog_service.dart';
import 'exercise_library_service.dart';
import 'program_service.dart';
import 'workout_service.dart';

// Где используется своё упражнение: сколько тренировок и программ
// содержат упражнения с его templateId.
class ExerciseUsage {
  final int workouts;
  final int programs;

  const ExerciseUsage({this.workouts = 0, this.programs = 0});

  bool get isUsed => workouts > 0 || programs > 0;
}

// Своё упражнение вместе с его использованием (для экрана «Мои упражнения»).
class CustomExerciseEntry {
  final ExerciseTemplate template;
  final ExerciseUsage usage;

  const CustomExerciseEntry(this.template, this.usage);
}

// Управление своими упражнениями: объединение, переименование, смена группы,
// удаление. Меняет библиотеку, тренировки и программы, поэтому живёт отдельно.
// Объединение и переименование переписывают сохранённые названия («снимки»)
// в тренировках и программах — это явное действие пользователя.
class CustomExerciseService {
  static final CustomExerciseService _instance =
      CustomExerciseService._internal();
  factory CustomExerciseService() => _instance;
  CustomExerciseService._internal();

  final _library = ExerciseLibraryService();
  final _workouts = WorkoutService();
  final _programs = ProgramService();

  // Список своих упражнений для экрана, самые используемые сверху.
  // Заодно убирает из библиотеки неиспользуемые дубликаты встроенных
  // (их упражнения уже привязаны к встроенным). Дубликаты, которые ещё
  // где-то используются, остаются скрытыми и в список не попадают.
  Future<List<CustomExerciseEntry>> loadEntries() async {
    final catalog = ExerciseCatalogService();
    await catalog.init();
    final usage = await _usageById();
    final custom = await _library.getCustomExercises();

    final unusedDuplicates = custom
        .where((t) =>
            catalog.isBuiltInDuplicate(t) && !(usage[t.id]?.isUsed ?? false))
        .map((t) => t.id)
        .toSet();
    if (unusedDuplicates.isNotEmpty) {
      await _library.saveCustomExercises(
          custom.where((t) => !unusedDuplicates.contains(t.id)).toList());
    }

    final entries = [
      for (final t in custom)
        if (!catalog.isBuiltInDuplicate(t))
          CustomExerciseEntry(t, usage[t.id] ?? const ExerciseUsage()),
    ];
    entries.sort((a, b) {
      final byWorkouts = b.usage.workouts.compareTo(a.usage.workouts);
      if (byWorkouts != 0) return byWorkouts;
      final byPrograms = b.usage.programs.compareTo(a.usage.programs);
      if (byPrograms != 0) return byPrograms;
      return a.template.nameRu.toLowerCase().compareTo(b.template.nameRu.toLowerCase());
    });
    return entries;
  }

  // Использование одного упражнения
  Future<ExerciseUsage> usageOf(String templateId) async =>
      (await _usageById())[templateId] ?? const ExerciseUsage();

  // templateId → сколько тренировок и программ его содержат
  // (тренировка / программа считается один раз, сколько бы раз упражнение в ней ни было)
  Future<Map<String, ExerciseUsage>> _usageById() async {
    final workoutCount = <String, int>{};
    for (final workout in await _workouts.loadAllWorkouts()) {
      final ids = {
        for (final e in workout.exercises)
          if (e.templateId != null) e.templateId!,
      };
      for (final id in ids) {
        workoutCount[id] = (workoutCount[id] ?? 0) + 1;
      }
    }
    final programCount = <String, int>{};
    for (final program in await _programs.loadAllPrograms()) {
      final ids = {
        for (final day in program.workouts)
          for (final e in day.exercises)
            if (e.templateId != null) e.templateId!,
      };
      for (final id in ids) {
        programCount[id] = (programCount[id] ?? 0) + 1;
      }
    }
    return {
      for (final id in {...workoutCount.keys, ...programCount.keys})
        id: ExerciseUsage(
          workouts: workoutCount[id] ?? 0,
          programs: programCount[id] ?? 0,
        ),
    };
  }

  // Объединить своё упражнение с другим (встроенным или своим):
  // все упражнения тренировок и программ с sourceId получают id, название
  // на текущем языке и группу мышц цели; исходное упражнение удаляется
  // из библиотеки. Если у цели нет группы, у упражнений остаётся прежняя.
  Future<void> merge({
    required String sourceId,
    required ExerciseTemplate target,
    required String languageCode,
  }) async {
    if (sourceId == target.id) return;
    final name = target.getName(languageCode).trim().isNotEmpty
        ? target.getName(languageCode)
        : target.nameRu;
    final group = target.muscleGroup;

    final workouts = await _workouts.loadAllWorkouts();
    final programs = await _programs.loadAllPrograms();
    final changed = repointExercises(
      workouts: workouts,
      programs: programs,
      sourceId: sourceId,
      target: target,
      name: name,
      workoutMuscleText:
          group.isNotEmpty ? 'workout.muscle_$group'.tr() : null,
    );
    if (changed.workouts) await _workouts.saveAllWorkouts(workouts);
    if (changed.programs) await _programs.saveAllPrograms(programs);

    final custom = await _library.getCustomExercises();
    await _library.saveCustomExercises(
        custom.where((t) => t.id != sourceId).toList());
  }

  // Сама замена при объединении — в памяти, без сохранения (её же
  // использует автоматическое объединение с новыми встроенными,
  // BuiltinExerciseMerge). Упражнения тренировок и программ с sourceId
  // получают id цели и название name; если у цели есть группа —
  // у тренировок muscleGroup + текст workoutMuscleText (null — текст
  // не трогаем), у программ ключ группы. Возвращает, что изменилось.
  static ({bool workouts, bool programs}) repointExercises({
    required List<Workout> workouts,
    required List<TrainingProgram> programs,
    required String sourceId,
    required ExerciseTemplate target,
    required String name,
    String? workoutMuscleText,
  }) {
    final group = target.muscleGroup;
    var workoutsChanged = false;
    for (final workout in workouts) {
      for (final e in workout.exercises) {
        if (e.templateId != sourceId) continue;
        e.templateId = target.id;
        e.name = name;
        if (group.isNotEmpty) {
          e.muscleGroup = group;
          if (workoutMuscleText != null) e.targetMuscle = workoutMuscleText;
        }
        workoutsChanged = true;
      }
    }
    var programsChanged = false;
    for (final program in programs) {
      for (final day in program.workouts) {
        for (final e in day.exercises) {
          if (e.templateId != sourceId) continue;
          e.templateId = target.id;
          e.name = name;
          if (group.isNotEmpty) e.targetMuscle = group;
          programsChanged = true;
        }
      }
    }
    return (workouts: workoutsChanged, programs: programsChanged);
  }

  // Проверить новое название: null — можно сохранить, 'empty' — пустое,
  // иначе id упражнения (встроенного или другого своего) с таким же названием.
  String? renameConflict(String id, String newName) {
    if (ExerciseCatalogService.normalize(newName).isEmpty) return 'empty';
    final existingId = ExerciseCatalogService().idForName(newName);
    return existingId == null || existingId == id ? null : existingId;
  }

  // Переименовать своё упражнение: все три названия в библиотеке и
  // сохранённые названия упражнений тренировок и программ с этим id.
  Future<void> rename(String id, String newName) async {
    final name = newName.trim();
    final custom = await _library.getCustomExercises();
    final index = custom.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final old = custom[index];
    custom[index] = ExerciseTemplate(
      id: old.id,
      nameRu: name,
      nameLv: name,
      nameEn: name,
      muscleGroup: old.muscleGroup,
      isCustom: true,
    );
    await _library.saveCustomExercises(custom);

    await _updateWorkoutExercises(id, (e) => e.name = name);
    await _updateProgramExercises(id, (e) => e.name = name);
  }

  // Сменить группу мышц своего упражнения: в библиотеке, у упражнений
  // тренировок (muscleGroup + переведённый текст) и программ (ключ группы).
  Future<void> setMuscleGroup(String id, String group) async {
    final custom = await _library.getCustomExercises();
    final index = custom.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final old = custom[index];
    custom[index] = ExerciseTemplate(
      id: old.id,
      nameRu: old.nameRu,
      nameLv: old.nameLv,
      nameEn: old.nameEn,
      muscleGroup: group,
      isCustom: true,
    );
    await _library.saveCustomExercises(custom);

    await _updateWorkoutExercises(id, (e) {
      e.muscleGroup = group;
      e.targetMuscle = 'workout.muscle_$group'.tr();
    });
    await _updateProgramExercises(id, (e) => e.targetMuscle = group);
  }

  // Удалить своё упражнение, только если оно нигде не используется.
  // Возвращает false, если используется (или не найдено).
  Future<bool> delete(String id) async {
    if ((await usageOf(id)).isUsed) return false;
    final custom = await _library.getCustomExercises();
    final kept = custom.where((t) => t.id != id).toList();
    if (kept.length == custom.length) return false;
    await _library.saveCustomExercises(kept);
    return true;
  }

  // Изменить все упражнения тренировок с этим templateId (сохраняем, только если нашлись)
  Future<void> _updateWorkoutExercises(
      String templateId, void Function(Exercise exercise) change) async {
    final workouts = await _workouts.loadAllWorkouts();
    var changed = false;
    for (final workout in workouts) {
      for (final e in workout.exercises) {
        if (e.templateId == templateId) {
          change(e);
          changed = true;
        }
      }
    }
    if (changed) await _workouts.saveAllWorkouts(workouts);
  }

  // То же для упражнений дней программ
  Future<void> _updateProgramExercises(
      String templateId, void Function(ProgramExercise exercise) change) async {
    final programs = await _programs.loadAllPrograms();
    var changed = false;
    for (final program in programs) {
      for (final day in program.workouts) {
        for (final e in day.exercises) {
          if (e.templateId == templateId) {
            change(e);
            changed = true;
          }
        }
      }
    }
    if (changed) await _programs.saveAllPrograms(programs);
  }
}
