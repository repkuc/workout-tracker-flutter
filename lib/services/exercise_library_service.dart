import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise_template.dart';
import 'workout_service.dart';



// Сервис для управления библиотекой упражнений.
// Этот файл содержит логику работы с базой упражнений: чтение встроенных упражнений,
// работу с пользовательскими упражнениями, поиск и перенос упражнений из истории.
class ExerciseLibraryService {
  // Ключ для хранения списка пользовательских упражнений в SharedPreferences.
  static const String _customKey = 'wt.custom_exercises.v1';
  // Ключ, по которому запоминается, была ли выполнена однажды миграция упражнений из истории.
  static const String _migratedKey = 'wt.exercises_migrated.v1';

  // Singleton: создаём один экземпляр сервиса и возвращаем его везде, где нужен доступ.
  static final ExerciseLibraryService _instance = ExerciseLibraryService._internal();

  // Фабричный конструктор возвращает заранее созданный единственный экземпляр.
  factory ExerciseLibraryService() => _instance;

  // Приватный конструктор, который используется только внутри класса при создании singleton.
  ExerciseLibraryService._internal();

  // Загрузить встроенные упражнения из assets.
  // Это упражнения, которые идут вместе с приложением и не сохраняются в SharedPreferences.
  Future<List<ExerciseTemplate>> getBuiltInExercises() async {
    // Загружаем файл с упражнениями из каталога assets приложения.
    final jsonStr = await rootBundle.loadString('assets/exercises/exercises.json');

    // Декодируем JSON-строку в динамическую структуру Dart.
    final List<dynamic> jsonList = json.decode(jsonStr);

    // Преобразуем каждый элемент JSON в объект ExerciseTemplate и возвращаем список.
    return jsonList.map((e) => ExerciseTemplate.fromJson(e)).toList();
  }

  // Загрузить пользовательские упражнения из SharedPreferences.
  // Эти упражнения добавляет сам пользователь через интерфейс приложения.
  Future<List<ExerciseTemplate>> getCustomExercises() async {
    // Получаем объект SharedPreferences для чтения данных из локального хранилища.
    final prefs = await SharedPreferences.getInstance();

    // Читаем строку JSON по ключу _customKey.
    final jsonStr = prefs.getString(_customKey);

    // Если данных нет, возвращаем пустой список, чтобы дальше не было ошибок.
    if (jsonStr == null) return [];

    // Декодируем JSON-строку в список элементов.
    final List<dynamic> jsonList = json.decode(jsonStr);

    // Преобразуем каждый элемент в объект ExerciseTemplate.
    return jsonList.map((e) => ExerciseTemplate.fromJson(e)).toList();
  }

  // Получить все упражнения: сначала встроенные, потом пользовательские.
  Future<List<ExerciseTemplate>> getAllExercises() async {
    // Получаем список встроенных упражнений.
    final builtIn = await getBuiltInExercises();

    // Получаем список пользовательских упражнений.
    final custom = await getCustomExercises();

    // Объединяем оба списка в один и возвращаем его.
    return [...builtIn, ...custom];
  }

  // Добавить своё упражнение в пользовательскую базу.
  Future<void> addCustomExercise({
    required String nameRu,
    required String nameLv,
    required String nameEn,
    String muscleGroup = '',
  }) async {
    // Получаем SharedPreferences для записи нового упражнения.
    final prefs = await SharedPreferences.getInstance();

    // Считываем уже существующий список пользовательских упражнений.
    final existing = await getCustomExercises();

    // Создаём объект нового упражнения с уникальным id.
    final newExercise = ExerciseTemplate(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      nameRu: nameRu,
      nameLv: nameLv,
      nameEn: nameEn,
      muscleGroup: muscleGroup,
      isCustom: true,
    );

    // Добавляем новое упражнение в список пользовательских.
    existing.add(newExercise);

    // Сохраняем обновлённый список обратно в SharedPreferences.
    await prefs.setString(
      _customKey,
      json.encode(existing.map((e) => e.toJson()).toList()),
    );
  }

  // Поиск упражнений по названию и опциональной группе мышц.
  Future<List<ExerciseTemplate>> searchExercises(
    String query,
    String languageCode, {
    String? muscleGroup,
  }) async {
    // Получаем все упражнения из библиотеки.
    final all = await getAllExercises();

    // Приводим поисковую строку к нижнему регистру и убираем пробелы по краям,
    // чтобы поиска был нечувствителен к регистру и пробелам.
    final q = query.toLowerCase().trim();

    return all.where((e) {
      // Если задан фильтр по группе мышц, проверяем, подходит ли упражнение.
      if (muscleGroup != null && muscleGroup.isNotEmpty && muscleGroup != 'all') {
        if (e.muscleGroup != muscleGroup) return false;
      }

      // Если текст запроса пуст, возвращаем упражнение без проверки названия.
      if (q.isEmpty) return true;

      // Получаем название упражнения на выбранном языке и проверяем, содержит ли оно запрос.
      return e.getName(languageCode).toLowerCase().contains(q);
    }).toList();
  }

  // Миграция — собрать упражнения из истории и добавить в личную базу, если они ещё не сохранены.
  Future<void> migrateExistingExercises() async {
    final prefs = await SharedPreferences.getInstance();

    // Проверяем что миграция ещё не выполнялась
    final migrated = prefs.getBool(_migratedKey) ?? false;
    if (migrated) return;

    final workoutService = WorkoutService();
    final workouts = await workoutService.getCompletedWorkouts();
    final builtIn = await getBuiltInExercises();
    final builtInNames = builtIn.map((e) => e.nameRu.toLowerCase()).toSet();

    // Собираем уникальные названия из истории
    final Map<String, String> uniqueExercises = {}; // name → targetMuscle
    for (final workout in workouts) {
      for (final exercise in workout.exercises) {
        if (!uniqueExercises.containsKey(exercise.name)) {
          uniqueExercises[exercise.name] = exercise.targetMuscle;
        }
      }
    }

    // Добавляем только те которых нет в встроенной базе
    final custom = await getCustomExercises();
    final customNames = custom.map((e) => e.nameRu.toLowerCase()).toSet();

    for (final entry in uniqueExercises.entries) {
      final name = entry.key;
      final muscle = entry.value;

      // Пропускаем если уже есть в базе
      if (builtInNames.contains(name.toLowerCase())) continue;
      if (customNames.contains(name.toLowerCase())) continue;

      custom.add(ExerciseTemplate(
        id: 'migrated_${DateTime.now().millisecondsSinceEpoch}_${custom.length}',
        nameRu: name,
        nameLv: name, // используем то же название
        nameEn: name,
        muscleGroup: muscle,
        isCustom: true,
      ));
    }

    await prefs.setString(
      _customKey,
      json.encode(custom.map((e) => e.toJson()).toList()),
    );

    // Отмечаем что миграция выполнена
    await prefs.setBool(_migratedKey, true);
  }
}