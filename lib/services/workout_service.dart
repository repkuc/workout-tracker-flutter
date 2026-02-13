import 'dart:convert'; // для json
import 'package:shared_preferences/shared_preferences.dart'; // для сохранения данных
import 'package:uuid/uuid.dart'; // для генерации уникальных ID
import '../models/workout_models.dart'; // импорт моделей

// Сервис для работы с тренировками (аналог workouts.js)
class WorkoutService {
  // Ключи для SharedPreferences (аналог localStorage)
  static const String _workoutsKey = 'wt.workouts.v1';
  static const String _currentWorkoutIdKey = 'wt.currentWorkoutId.v1';

  // Генератор уникальных ID
  final _uuid = const Uuid();

  // Singleton паттерн (один экземпляр на всё приложение)
  static final WorkoutService _instance = WorkoutService._internal();
  factory WorkoutService() => _instance;
  WorkoutService._internal();

  // Кэш для быстрого доступа
  SharedPreferences? _prefs;
  // Инициализация SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Получить SharedPreferences
  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // === ЗАГРУЗКА/СОХРАНЕНИЕ ===

  // Загрузить все тренировки
  Future<List<Workout>> loadAllWorkouts() async {
    final prefs = await _preferences; // Получаем SharedPreferences
    final jsonString = prefs.getString(_workoutsKey); // Получаем JSON строку

    if (jsonString == null || jsonString.isEmpty) {
      return []; // Если нет данных, возвращаем пустой список
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Workout.fromJson(json)).toList();
    } catch (e) {
      // Если произошла ошибка при парсинге, возвращаем пустой список
      print('Error parsing workouts JSON: $e');
      return [];
    }
  }

  // Сохранить все тренировки
  Future<void> saveAllWorkouts(List<Workout> workouts) async {
    final prefs = await _preferences;
    final jsonString = json.encode(workouts.map((w) => w.toJson()).toList());
    await prefs.setString(_workoutsKey, jsonString);
  }

  // Получить ID текущей тренировки (черновик)
  Future<String?> getCurrentWorkoutId() async {
    final prefs = await _preferences;
    return prefs.getString(_currentWorkoutIdKey);
  }

  // Установить ID текущей тренировки
  Future<void> setCurrentWorkoutId(String? id) async {
    final prefs = await _preferences;
    if (id == null || id.isEmpty) {
      await prefs.remove(_currentWorkoutIdKey);
    } else {
      await prefs.setString(_currentWorkoutIdKey, id);
    }
  }

  // === РАБОТА С ТРЕНИРОВКАМИ ===

  // Создать новую тренировку
  Future<Workout> createWorkout({
    required String date,
    String name = 'Тренировка',
    String notes = '',
  }) async {
    final workout = Workout(
      id: _uuid.v4(),
      date: date,
      name: name,
      notes: notes,
      status: 'draft',
    );

    final workouts = await loadAllWorkouts();
    workouts.add(workout);
    await saveAllWorkouts(workouts);
    await setCurrentWorkoutId(workout.id);

    return workout;
  }

  // Получить тренировку по ID
  Future<Workout?> getWorkout(String id) async {
    final workouts = await loadAllWorkouts();
    try {
      return workouts.firstWhere((w) => w.id == id);
    } catch (e) {
      return null;
    }
  }

  // Получить текущий черновик
  Future<Workout?> getDraftWorkout() async {
    final currentId = await getCurrentWorkoutId();
    if (currentId == null) return null;

    final workout = await getWorkout(currentId);
    if (workout?.status == 'draft') {
      return workout;
    }
    return null;
  }

  // Получить список завершённых тренировок
  Future<List<Workout>> getCompletedWorkouts() async {
    final workouts = await loadAllWorkouts();
    final completed = workouts.where((w) => w.status == 'done').toList();

    // Сортируем по дате (новые первые)
    completed.sort((a, b) {
      final aKey = a.finishedAt ?? '${a.date}T00:00:00';
      final bKey = b.finishedAt ?? '${b.date}T00:00:00';
      return bKey.compareTo(aKey);
    });

    return completed;
  }

  // Завершить тренировку
  Future<bool> finishWorkout(String id) async {
    final workouts = await loadAllWorkouts();
    final index = workouts.indexWhere((w) => w.id == id);

    if (index == -1) return false;

    workouts[index].status = 'done';
    workouts[index].finishedAt = DateTime.now().toIso8601String();

    await saveAllWorkouts(workouts);

    // Очищаем ID текущей тренировки
    final currentId = await getCurrentWorkoutId();
    if (currentId == id) {
      await setCurrentWorkoutId(null);
    }

    return true;
  }

  // Удалить тренировку
  Future<bool> deleteWorkout(String id) async {
    final workouts = await loadAllWorkouts();
    final index = workouts.indexWhere((w) => w.id == id);

    if (index == -1) return false;

    workouts.removeAt(index);
    await saveAllWorkouts(workouts);

    // Очищаем ID если это текущая
    final currentId = await getCurrentWorkoutId();
    if (currentId == id) {
      await setCurrentWorkoutId(null);
    }

    return true;
  }

  // === РАБОТА С УПРАЖНЕНИЯМИ ===

  // Добавить упражнение в тренировку
  Future<bool> addExercise(
    String workoutId, {
    required String name,
    String targetMuscle = '',
  }) async {
    final workouts = await loadAllWorkouts();
    final index = workouts.indexWhere((w) => w.id == workoutId);

    if (index == -1) return false;

    final exercise = Exercise(
      id: _uuid.v4(),
      workoutId: workoutId,
      name: name,
      targetMuscle: targetMuscle,
      position: workouts[index].exercises.length,
    );

    workouts[index].exercises.add(exercise);
    await saveAllWorkouts(workouts);

    return true;
  }

  // Удалить упражнение
  Future<bool> removeExercise(String workoutId, String exerciseId) async {
    final workouts = await loadAllWorkouts();
    final wIndex = workouts.indexWhere((w) => w.id == workoutId);

    if (wIndex == -1) return false;

    workouts[wIndex].exercises.removeWhere((e) => e.id == exerciseId);
    await saveAllWorkouts(workouts);

    return true;
  }

  // Обновить упражнение (название, целевую мышцу)
  Future<bool> updateExercise(
    String workoutId,
    String exerciseId, {
    String? name,
    String? targetMuscle,
  }) async {
    final workouts = await loadAllWorkouts();
    final wIndex = workouts.indexWhere((w) => w.id == workoutId);

    if (wIndex == -1) return false;

    final eIndex =
        workouts[wIndex].exercises.indexWhere((e) => e.id == exerciseId);
    if (eIndex == -1) return false;

    // Обновляем только те поля, которые переданы
    if (name != null) {
      workouts[wIndex].exercises[eIndex].name = name;
    }
    if (targetMuscle != null) {
      workouts[wIndex].exercises[eIndex].targetMuscle = targetMuscle;
    }

    await saveAllWorkouts(workouts);
    return true;
  }

  // === РАБОТА С ПОДХОДАМИ ===

  // Добавить подход к упражнению
  Future<bool> addSet(
    String workoutId,
    String exerciseId, {
    required int reps,
    required double weight,
  }) async {
    final workouts = await loadAllWorkouts();
    final wIndex = workouts.indexWhere((w) => w.id == workoutId);

    if (wIndex == -1) return false;

    final eIndex =
        workouts[wIndex].exercises.indexWhere((e) => e.id == exerciseId);
    if (eIndex == -1) return false;

    final set = WorkoutSet(
      id: _uuid.v4(),
      exerciseId: exerciseId,
      reps: reps,
      weight: weight,
      isDone: false,
    );

    workouts[wIndex].exercises[eIndex].sets.add(set);
    await saveAllWorkouts(workouts);

    return true;
  }

  // Удалить подход
  Future<bool> removeSet(
      String workoutId, String exerciseId, String setId) async {
    final workouts = await loadAllWorkouts();
    final wIndex = workouts.indexWhere((w) => w.id == workoutId);

    if (wIndex == -1) return false;

    final eIndex =
        workouts[wIndex].exercises.indexWhere((e) => e.id == exerciseId);
    if (eIndex == -1) return false;

    workouts[wIndex].exercises[eIndex].sets.removeWhere((s) => s.id == setId);
    await saveAllWorkouts(workouts);

    return true;
  }

  // Обновить подход (отметить выполнение, изменить вес/повторы)
  Future<bool> updateSet(
    String workoutId,
    String exerciseId,
    String setId, {
    int? reps,
    double? weight,
    bool? isDone,
  }) async {
    final workouts = await loadAllWorkouts();
    final wIndex = workouts.indexWhere((w) => w.id == workoutId);

    if (wIndex == -1) return false;

    final eIndex =
        workouts[wIndex].exercises.indexWhere((e) => e.id == exerciseId);
    if (eIndex == -1) return false;

    final sIndex = workouts[wIndex]
        .exercises[eIndex]
        .sets
        .indexWhere((s) => s.id == setId);
    if (sIndex == -1) return false;

    final set = workouts[wIndex].exercises[eIndex].sets[sIndex];

    // Создаём новый подход с обновлёнными данными
    workouts[wIndex].exercises[eIndex].sets[sIndex] = WorkoutSet(
      id: set.id,
      exerciseId: set.exerciseId,
      reps: reps ?? set.reps,
      weight: weight ?? set.weight,
      isDone: isDone ?? set.isDone,
    );

    await saveAllWorkouts(workouts);
    return true;
  }

  // Обновить мета-информацию тренировки (имя, дату, заметки)
  Future<bool> updateWorkoutMeta(
    String workoutId, {
    String? name,
    String? date,
    String? notes,
  }) async {
    final workouts = await loadAllWorkouts();
    final index = workouts.indexWhere((w) => w.id == workoutId);

    if (index == -1) return false;

    if (name != null) workouts[index].name = name;
    if (date != null) workouts[index].date = date;
    if (notes != null) workouts[index].notes = notes;

    await saveAllWorkouts(workouts);
    return true;
  }

  // Скопировать тренировку (создать новую на основе существующей)
Future<Workout> copyWorkout(String workoutId) async {
  // Загружаем оригинальную тренировку
  final original = await getWorkout(workoutId);
  if (original == null) {
    throw Exception('Workout not found');
  }
  
  // Создаём новую тренировку с тем же названием
  final newWorkout = Workout(
    id: _uuid.v4(),
    date: getTodayDate(),
    name: original.name, // ← То же название
    notes: original.notes,
    status: 'draft', // ← Новая тренировка - черновик
  );
  
  // Копируем все упражнения
  for (final exercise in original.exercises) {
    final newExercise = Exercise(
      id: _uuid.v4(),
      workoutId: newWorkout.id,
      name: exercise.name,
      targetMuscle: exercise.targetMuscle,
      position: exercise.position,
    );
    
    // Копируем все подходы (но делаем их невыполненными)
    for (final set in exercise.sets) {
      final newSet = WorkoutSet(
        id: _uuid.v4(),
        exerciseId: newExercise.id,
        reps: set.reps, // ← Те же повторы
        weight: set.weight, // ← Тот же вес
        isDone: false, // ← НЕ выполнен (важно!)
      );
      newExercise.sets.add(newSet);
    }
    
    newWorkout.exercises.add(newExercise);
  }
  
  // Сохраняем новую тренировку
  final workouts = await loadAllWorkouts();
  workouts.add(newWorkout);
  await saveAllWorkouts(workouts);
  
  // Устанавливаем как текущую тренировку
  await setCurrentWorkoutId(newWorkout.id);
  
  return newWorkout;
}

  // Получить сегодняшнюю дату в формате YYYY-MM-DD
  String getTodayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
