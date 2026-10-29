import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';
import '../models/builtin_program.dart';
import '../models/program_models.dart';
import 'exercise_catalog_service.dart';
import 'program_service.dart';

// Готовые программы из assets/programs/builtin_programs.json.
// Хранятся только в файле: в SharedPreferences и бэкап не попадают.
// «Добавить в мои программы» создаёт обычную программу пользователя —
// копию на текущем языке, никак не связанную с готовой.
class BuiltinProgramService {
  static const String _assetPath = 'assets/programs/builtin_programs.json';

  static final BuiltinProgramService _instance =
      BuiltinProgramService._internal();
  factory BuiltinProgramService() => _instance;
  BuiltinProgramService._internal();

  final _uuid = const Uuid();
  List<BuiltinProgram>? _cache;

  // Все готовые программы (файл читаем один раз). Упражнения с неизвестным
  // id шаблона пропускаем (debugPrint); битый файл — пустой список, без падения.
  Future<List<BuiltinProgram>> loadPrograms() async {
    if (_cache != null) return _cache!;
    await ExerciseCatalogService().init();
    try {
      final data = json.decode(await rootBundle.loadString(_assetPath));
      final programs = ((data['programs'] as List?) ?? [])
          .map((p) => _withKnownExercises(BuiltinProgram.fromJson(p)))
          .toList();
      return _cache = programs;
    } catch (e) {
      debugPrint('BuiltinProgramService: cannot load $_assetPath: $e');
      return _cache = [];
    }
  }

  // Убрать упражнения, которых нет среди встроенных в каталоге.
  BuiltinProgram _withKnownExercises(BuiltinProgram program) {
    final catalog = ExerciseCatalogService();
    return BuiltinProgram(
      id: program.id,
      names: program.names,
      descriptions: program.descriptions,
      scheduleDays: program.scheduleDays,
      days: program.days.map((day) {
        final known = day.exercises.where((e) {
          final template = catalog.templateById(e.templateId);
          if (template != null && !template.isCustom) return true;
          debugPrint('BuiltinProgramService: ${program.id}/${day.id}: '
              'unknown templateId "${e.templateId}", skipped');
          return false;
        }).toList();
        return BuiltinProgramDay(id: day.id, names: day.names, exercises: known);
      }).toList(),
    );
  }

  // Упражнение дня как ProgramExercise на нужном языке: название — снимок
  // текущего названия шаблона, targetMuscle — ключ группы из каталога.
  // Нужен и для просмотра, и для копии, чтобы они выглядели одинаково.
  ProgramExercise toProgramExercise(
      BuiltinProgramExercise exercise, String languageCode) {
    final template = ExerciseCatalogService().templateById(exercise.templateId);
    return ProgramExercise(
      name: ExerciseCatalogService().displayName(
        templateId: exercise.templateId,
        name: exercise.templateId,
        languageCode: languageCode,
      ),
      targetMuscle: template?.muscleGroup ?? '',
      templateId: exercise.templateId,
      targetSets: exercise.sets,
      repsMin: exercise.repsMin,
      repsMax: exercise.repsMax,
    )..normalizeRepsRange();
  }

  // Добавить копию готовой программы в «мои программы»: новые id программы
  // и дней, тексты на текущем языке. Дальше это обычная программа
  // пользователя; повторное добавление создаёт ещё одну копию.
  Future<TrainingProgram> addToMyPrograms(
      BuiltinProgram builtin, String languageCode) async {
    final program = TrainingProgram(
      id: _uuid.v4(),
      name: builtin.name(languageCode),
      description: builtin.description(languageCode),
      scheduleDays: List.of(builtin.scheduleDays),
      workouts: builtin.days
          .map((day) => ProgramWorkout(
                id: _uuid.v4(),
                name: day.name(languageCode),
                exercises: day.exercises
                    .map((e) => toProgramExercise(e, languageCode))
                    .toList(),
              ))
          .toList(),
      isCustom: true,
    );
    await ProgramService().addProgram(program);
    return program;
  }
}
