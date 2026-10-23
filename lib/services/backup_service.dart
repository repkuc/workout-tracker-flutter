import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'workout_service.dart';
import 'body_weight_service.dart';
// Новые сервисы которые ещё не были подключены к бэкапу.
import 'body_measurement_service.dart';
import 'program_service.dart';
import 'exercise_library_service.dart';
import '../models/body_measurement_entry.dart';
import '../models/exercise_template.dart';
import '../models/program_models.dart';

class BackupService {
  final _workoutService = WorkoutService();
  final _bodyWeightService = BodyWeightService();
  // Подключаем новые сервисы.
  final _bodyMeasurementService = BodyMeasurementService();
  final _programService = ProgramService();
  final _exerciseLibraryService = ExerciseLibraryService();

  // Сколько пользовательских упражнений при последнем импорте пропущено:
  // такой id уже есть, но с другим названием (оставляем локальное).
  int skippedCustomExerciseConflicts = 0;

  // ЭКСПОРТ — сохраняем тренировки, вес тела, замеры тела, программы
  // и пользовательские упражнения.
  Future<void> exportData() async {
    final jsonData = await buildExportJson();

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/workout_diary_backup.json');
    await file.writeAsString(jsonData);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Workout Diary backup',
    );
  }

  // Собрать JSON бэкапа (без отправки файла).
  Future<String> buildExportJson() async {
    final workouts = await _workoutService.loadAllWorkouts();
    final weightEntries = await _bodyWeightService.getAllEntries();
    // Загружаем замеры тела и программы для включения в бэкап.
    final measurementEntries = await _bodyMeasurementService.loadAllEntries();
    final programs = await _programService.loadAllPrograms();
    final customExercises = await _exerciseLibraryService.getCustomExercises();

    return json.encode({
      'workouts': workouts.map((w) => w.toJson()).toList(),
      'bodyWeight': weightEntries.map((e) => e.toJson()).toList(),
      // Новые ключи в бэкапе — старые версии приложения при импорте
      // просто проигнорируют их, так как не знают об этих полях.
      'bodyMeasurements': measurementEntries.map((e) => e.toJson()).toList(),
      'programs': programs.map((p) => p.toJson()).toList(),
      // Только пользовательские упражнения — встроенные идут вместе с приложением.
      'customExercises': customExercises.map((e) => e.toJson()).toList(),
    });
  }

  // ИМПОРТ — читаем тренировки, вес тела, замеры тела и программы.
  Future<int> importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) {
      return 0;
    }

    final file = File(result.files.single.path!);
    final jsonString = await file.readAsString();
    return importDecoded(json.decode(jsonString));
  }

  // Импорт уже разобранного JSON бэкапа. Возвращает число новых тренировок.
  Future<int> importDecoded(dynamic decoded) async {
    int imported = 0;
    skippedCustomExerciseConflicts = 0;

    if (decoded is List) {
      // Старый формат — только список тренировок.
      imported += await _importWorkouts(decoded);
    } else if (decoded is Map) {
      // Пользовательские упражнения — первыми, до тренировок и программ,
      // которые на них ссылаются. В старом бэкапе ключа нет — пропускаем.
      if (decoded['customExercises'] != null) {
        skippedCustomExerciseConflicts =
            await _importCustomExercises(decoded['customExercises'] as List);
      }
      if (decoded['workouts'] != null) {
        imported += await _importWorkouts(decoded['workouts'] as List);
      }
      if (decoded['bodyWeight'] != null) {
        await _importBodyWeight(decoded['bodyWeight'] as List);
      }
      // Импортируем замеры тела, если они есть в файле бэкапа.
      // Если бэкап старый и этого ключа нет — просто пропускаем,
      // никакой ошибки не будет благодаря проверке на null.
      if (decoded['bodyMeasurements'] != null) {
        await _importBodyMeasurements(decoded['bodyMeasurements'] as List);
      }
      // Импортируем программы тренировок.
      if (decoded['programs'] != null) {
        await _importPrograms(decoded['programs'] as List);
      }
    }

    return imported;
  }

  // Импорт пользовательских упражнений, слияние по id:
  // нового id нет — добавляем; тот же id и то же название — пропускаем;
  // тот же id, но другое название — оставляем локальное, импортное пропускаем.
  // Встроенные упражнения не трогаем. Возвращает число таких конфликтов.
  Future<int> _importCustomExercises(List jsonList) async {
    final builtInIds = (await _exerciseLibraryService.getBuiltInExercises())
        .map((e) => e.id)
        .toSet();
    final existing = await _exerciseLibraryService.getCustomExercises();
    final existingById = {for (final e in existing) e.id: e};

    int conflicts = 0;
    bool changed = false;
    for (final item in jsonList) {
      final exercise =
          ExerciseTemplate.fromJson(item as Map<String, dynamic>);
      if (builtInIds.contains(exercise.id)) continue;

      final local = existingById[exercise.id];
      if (local == null) {
        // Импортированное упражнение всегда пользовательское
        final added = ExerciseTemplate(
          id: exercise.id,
          nameRu: exercise.nameRu,
          nameLv: exercise.nameLv,
          nameEn: exercise.nameEn,
          muscleGroup: exercise.muscleGroup,
          isCustom: true,
        );
        existing.add(added);
        existingById[added.id] = added;
        changed = true;
      } else if (!_sameName(local, exercise)) {
        conflicts++;
      }
    }

    if (changed) await _exerciseLibraryService.saveCustomExercises(existing);
    return conflicts;
  }

  static bool _sameName(ExerciseTemplate a, ExerciseTemplate b) =>
      a.nameRu.trim() == b.nameRu.trim() &&
      a.nameLv.trim() == b.nameLv.trim() &&
      a.nameEn.trim() == b.nameEn.trim();

  Future<int> _importWorkouts(List jsonList) async {
    final existing = await _workoutService.loadAllWorkouts();
    final existingIds = existing.map((w) => w.id).toSet();

    int imported = 0;
    for (final item in jsonList) {
      final id = item['id'] as String;
      if (!existingIds.contains(id)) {
        existing.add(_workoutService.workoutFromJson(item));
        imported++;
      }
    }

    await _workoutService.saveAllWorkouts(existing);
    return imported;
  }

  Future<void> _importBodyWeight(List jsonList) async {
    for (final item in jsonList) {
      final date = item['date'] as String;
      final weight = (item['weight'] as num).toDouble();
      await _bodyWeightService.saveEntryWithDate(date, weight);
    }
  }

  // Импорт замеров тела. Используем ту же логику "по дате" что и вес тела:
  // если на эту дату уже есть запись — она будет обновлена/объединена
  // через saveEntry (который сам ищет существующую запись по дате).
  Future<void> _importBodyMeasurements(List jsonList) async {
    for (final item in jsonList) {
      final entry = BodyMeasurementEntry.fromJson(item as Map<String, dynamic>);
      await _bodyMeasurementService.saveEntry(entry);
    }
  }

  // Импорт программ тренировок. Проверяем по id программы чтобы не
  // создавать дубликаты при повторном импорте одного и того же бэкапа.
  // Дни недели, описание и план повторов читает fromJson; в старом бэкапе
  // их нет — тогда берутся значения по умолчанию, а текстовое расписание
  // переносится в описание (миграция в TrainingProgram.fromJson).
  Future<void> _importPrograms(List jsonList) async {
    final existing = await _programService.loadAllPrograms();
    final existingIds = existing.map((p) => p.id).toSet();

    for (final item in jsonList) {
      final program = TrainingProgram.fromJson(item as Map<String, dynamic>);
      if (!existingIds.contains(program.id)) {
        existing.add(program);
      }
    }

    await _programService.saveAllPrograms(existing);
  }
}