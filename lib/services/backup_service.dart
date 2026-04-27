import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'workout_service.dart';
import 'body_weight_service.dart';

class BackupService {
  final _workoutService = WorkoutService();
  final _bodyWeightService = BodyWeightService();

  // ЭКСПОРТ — сохраняем тренировки И вес тела
  Future<void> exportData() async {
    final workouts = await _workoutService.loadAllWorkouts();
    final weightEntries = await _bodyWeightService.getAllEntries();

    // Упаковываем всё в один объект
    final jsonData = json.encode({
      'workouts': workouts.map((w) => w.toJson()).toList(),
      'bodyWeight': weightEntries.map((e) => e.toJson()).toList(),
    });

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/workout_diary_backup.json');
    await file.writeAsString(jsonData);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Workout Diary backup',
    );
  }

  // ИМПОРТ — читаем тренировки И вес тела
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
    final decoded = json.decode(jsonString);

    int imported = 0;

    // Поддержка старого формата (только список тренировок)
    // и нового формата (объект с workouts и bodyWeight)
    if (decoded is List) {
      // Старый формат — только тренировки
      imported += await _importWorkouts(decoded);
    } else if (decoded is Map) {
      // Новый формат — тренировки + вес
      if (decoded['workouts'] != null) {
        imported += await _importWorkouts(decoded['workouts'] as List);
      }
      if (decoded['bodyWeight'] != null) {
        await _importBodyWeight(decoded['bodyWeight'] as List);
      }
    }

    return imported;
  }

  // Импорт тренировок
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

  // Импорт веса тела
  Future<void> _importBodyWeight(List jsonList) async {
    for (final item in jsonList) {
      final date = item['date'] as String;
      final weight = (item['weight'] as num).toDouble();
      await _bodyWeightService.saveEntryWithDate(date, weight);
    }
  }
}
