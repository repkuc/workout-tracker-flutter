import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'workout_service.dart';

class BackupService {
  final _workoutService = WorkoutService();

  // ЭКСПОРТ — сохраняем все тренировки в JSON файл и делимся им
  Future<void> exportData() async {
    // Загружаем все тренировки
    final workouts = await _workoutService.loadAllWorkouts();

    // Превращаем список тренировок в JSON строку
    final jsonData = json.encode(
      workouts.map((w) => w.toJson()).toList(),
    );

    // Находим временную папку на телефоне
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/workout_diary_backup.json');

    // Записываем JSON в файл
    await file.writeAsString(jsonData);

    // Открываем стандартное меню "поделиться" Android
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Workout Diary backup',
    );
  }

  // ИМПОРТ — читаем JSON файл и загружаем тренировки
  // Возвращает количество импортированных тренировок
  Future<int> importData() async {
    // Открываем файловый менеджер — только JSON файлы
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    // Пользователь отменил выбор — возвращаем 0
    if (result == null || result.files.single.path == null) {
      return 0;
    }

    // Читаем содержимое файла
    final file = File(result.files.single.path!);
    final jsonString = await file.readAsString();

    // Парсим JSON строку обратно в список
    final List<dynamic> jsonList = json.decode(jsonString);

    // Загружаем существующие тренировки
    final existing = await _workoutService.loadAllWorkouts();

    // Собираем все существующие ID в Set для быстрой проверки
    final existingIds = existing.map((w) => w.id).toSet();

    // Добавляем только те тренировки которых ещё нет
    int imported = 0;
    for (final item in jsonList) {
      final id = item['id'] as String;
      if (!existingIds.contains(id)) {
        existing.add(_workoutService.workoutFromJson(item));
        imported++;
      }
    }

    // Сохраняем обновлённый список
    await _workoutService.saveAllWorkouts(existing);

    // Возвращаем сколько тренировок добавили
    return imported;
  }
}