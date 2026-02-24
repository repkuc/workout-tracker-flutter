// Подход (один сет упражнения)
class WorkoutSet {
  final String id; // Уникальный идентификатор сета
  final String exerciseId; // Идентификатор упражнения
  final int reps; // Количество повторений
  final double weight; // Вес в килограммах
  bool isDone; // Выполнен ли сет

  // Конструктор
  WorkoutSet({
    required this.id, //
    required this.exerciseId,
    required this.reps,
    required this.weight,
    this.isDone = false, // По умолчанию сет не выполнен
  });

  // Конвертация в JSON для сохранения
  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'reps': reps,
    'weight': weight,
    'isDone': isDone,
  };

  // Создание из JSON
  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
    id: json['id'],
    exerciseId: json['exerciseId'],
    reps: json['reps'],
    weight: json['weight'],
    isDone: json['isDone'] ?? false,
  );
}

// Упражнение (состоящее из нескольких сетов)
class Exercise {
  final String id; // Уникальный идентификатор упражнения
  final String workoutId; // Идентификатор тренировки
  String name; // Название упражнения
  String targetMuscle; // Целевая мышца
  List<WorkoutSet> sets; // Сеты упражнения
  int position; // Позиция упражнения в тренировке
  bool isCompleted; // Завершено ли упражнение
  String? copiedFromExerciseId; // Идентификатор упражнения, из которого было скопировано (если применимо)

  // Конструктор
  Exercise({
    required this.id,
    required this.workoutId,
    required this.name,
    this.targetMuscle = '', // По умолчанию пустая строка
    List<WorkoutSet>? sets,
    this.position = 0,
    this.isCompleted = false, // По умолчанию упражнение не завершено
    this.copiedFromExerciseId,
  }) : sets = sets ?? []; // Инициализация пустым списком, если не передан

  // Конвертация в JSON для сохранения
  Map<String, dynamic> toJson() => {
    'id': id,
    'workoutId': workoutId,
    'name': name,
    'targetMuscle': targetMuscle,
    'sets': sets.map((s) => s.toJson()).toList(),
    'position': position,
    'isCompleted': isCompleted,
    'copiedFromExerciseId': copiedFromExerciseId,
  };

  // Создание из JSON
  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'],
    workoutId: json['workoutId'],
    name: json['name'],
    targetMuscle: json['targetMuscle'] ?? '',
    sets: (json['sets'] as List?)
        ?.map((s) => WorkoutSet.fromJson(s))
        .toList() ??
        [],
    position: json['position'] ?? 0,
    isCompleted: json['isCompleted'] ?? false,
    copiedFromExerciseId: json['copiedFromExerciseId'],
  );
}

// Тренировка (состоящая из нескольких упражнений)
class Workout {
  final String id; // Уникальный идентификатор тренировки
  String date; // Дата тренировки в формате 'YYYY-MM-DD'
  String name; // Название тренировки
  String notes; // Заметки к тренировке
  String status; // Статус тренировки ('draft' или 'done')
  String? finishedAt; // Время завершения тренировки
  String? copiedFromWorkoutId; // Идентификатор тренировки, из которой была скопирована (если применимо)
  String? startedAt; // Время начала тренировки
  int? duration; // Длительность тренировки в секундах
  List<Exercise> exercises; // Упражнения в тренировке

  Workout({
    required this.id,
    required this.date,
    this.name = 'Workout',
    this.notes = '',
    this.status = 'draft',
    this.finishedAt,
    this.copiedFromWorkoutId,
    this.startedAt,
    this.duration,
    List<Exercise>? exercises,
  }) : exercises = exercises ?? [];

  // Конвертация в JSON для сохранения
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'name': name,
    'notes': notes,
    'status': status,
    'startedAt': startedAt,
    'duration': duration,
    'finishedAt': finishedAt,
    'copiedFromWorkoutId': copiedFromWorkoutId,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  // Создание из JSON
  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
    id: json['id'],
    date: json['date'],
    name: json['name'] ?? 'Workout',
    notes: json['notes'] ?? '',
    status: json['status'] ?? 'draft',
    finishedAt: json['finishedAt'],
    copiedFromWorkoutId: json['copiedFromWorkoutId'],
    startedAt: json['startedAt'],
    duration: json['duration'],
    exercises: (json['exercises'] as List?)
        ?.map((e) => Exercise.fromJson(e))
        .toList() ??
        [],
  );


}