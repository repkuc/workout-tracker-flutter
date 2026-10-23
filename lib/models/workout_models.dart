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
  String targetMuscle; // Целевая мышца (переведённый текст на момент добавления)
  // id шаблона из библиотеки (встроенный 'chest_1' или пользовательский 'custom_…').
  // null — ещё не привязано; name остаётся «снимком» и запасным вариантом.
  String? templateId;
  String? muscleGroup; // Ключ группы мышц ('chest'); null — неизвестно
  List<WorkoutSet> sets; // Сеты упражнения
  int position; // Позиция упражнения в тренировке
  bool isCompleted; // Завершено ли упражнение
  String? copiedFromExerciseId; // Идентификатор упражнения, из которого было скопировано (если применимо)
  // План из дня программы — «снимок» на момент Начать / Повторить, чтобы
  // поздние правки программы не меняли прошлые тренировки. null — плана нет
  // (упражнение добавлено вручную или тренировка не из программы).
  int? plannedSets; // Сколько подходов запланировано
  int? plannedRepsMin; // Повторы «от» (null — без плана повторов)
  int? plannedRepsMax; // Повторы «до»

  // Конструктор
  Exercise({
    required this.id,
    required this.workoutId,
    required this.name,
    this.targetMuscle = '', // По умолчанию пустая строка
    this.templateId,
    this.muscleGroup,
    List<WorkoutSet>? sets,
    this.position = 0,
    this.isCompleted = false, // По умолчанию упражнение не завершено
    this.copiedFromExerciseId,
    this.plannedSets,
    this.plannedRepsMin,
    this.plannedRepsMax,
  }) : sets = sets ?? []; // Инициализация пустым списком, если не передан

  // Есть ли у упражнения цель из программы
  bool get hasPlan => plannedSets != null;

  // Сколько подходов отмечено выполненными
  int get doneSetsCount => sets.where((s) => s.isDone).length;

  // Конвертация в JSON для сохранения
  Map<String, dynamic> toJson() => {
    'id': id,
    'workoutId': workoutId,
    'name': name,
    'targetMuscle': targetMuscle,
    'templateId': templateId,
    'muscleGroup': muscleGroup,
    'sets': sets.map((s) => s.toJson()).toList(),
    'position': position,
    'isCompleted': isCompleted,
    'copiedFromExerciseId': copiedFromExerciseId,
    'plannedSets': plannedSets,
    'plannedRepsMin': plannedRepsMin,
    'plannedRepsMax': plannedRepsMax,
  };

  // Создание из JSON
  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'],
    workoutId: json['workoutId'],
    name: json['name'],
    targetMuscle: json['targetMuscle'] ?? '',
    // В старых данных этих полей нет — будет null (заполняет миграция)
    templateId: json['templateId'],
    muscleGroup: json['muscleGroup'],
    sets: (json['sets'] as List?)
        ?.map((s) => WorkoutSet.fromJson(s))
        .toList() ??
        [],
    position: json['position'] ?? 0,
    isCompleted: json['isCompleted'] ?? false,
    copiedFromExerciseId: json['copiedFromExerciseId'],
    // В старых данных плана нет — будет null
    plannedSets: (json['plannedSets'] as num?)?.toInt(),
    plannedRepsMin: (json['plannedRepsMin'] as num?)?.toInt(),
    plannedRepsMax: (json['plannedRepsMax'] as num?)?.toInt(),
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
  String? color; // Цвет тренировки например "#F97316"
  String? pausedAt; // Время паузы тренировки
  int totalPausedSeconds; // Общее количество секунд, проведенных на паузе
  String? programId; // Идентификатор программы, если тренировка связана с программой
  String? programWorkoutName; // Название тренировки в программе, если применимо
  // ID дня программы (ProgramWorkout.id). Связь с днём ищется по нему, а не по
  // названию — переименование дня не теряет историю. У старых тренировок null:
  // для них остаётся поиск по programWorkoutName (см. getLastWorkoutForProgramDay).
  String? programWorkoutId;
  // Название самой программы на момент создания тренировки — сохраняем "снимок",
  // а не ищем программу заново по ID каждый раз. Так бейдж в истории останется
  // корректным даже если позже программу переименуют или удалят.
  String? programName;
  List<String> muscleGroups; // Группы мышц например ["chest", "back"]
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
    this.color,
    this.pausedAt,
    this.totalPausedSeconds = 0,
    List<String>? muscleGroups,
    List<Exercise>? exercises,
    this.programId,
    this.programWorkoutName,
    this.programWorkoutId,
    this.programName,
  }) : exercises = exercises ?? [], // Инициализация пустым списком, если не передан
      muscleGroups = muscleGroups ?? []; // Инициализация пустым списком, если не передан

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
    'color': color,
    'pausedAt': pausedAt,
    'totalPausedSeconds': totalPausedSeconds,
    'programId': programId,
    'programWorkoutName': programWorkoutName,
    'programWorkoutId': programWorkoutId,
    'programName': programName,
    'muscleGroups': muscleGroups,
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
    color: json['color'],
    pausedAt: json['pausedAt'],
    totalPausedSeconds: json['totalPausedSeconds'] ?? 0,
    programId: json['programId'],
    programWorkoutName: json['programWorkoutName'],
    programWorkoutId: json['programWorkoutId'],
    programName: json['programName'],
    muscleGroups: (json['muscleGroups'] as List?)
    ?.map((e) => e.toString())
    .toList() ?? [],
    exercises: (json['exercises'] as List?)
        ?.map((e) => Exercise.fromJson(e))
        .toList() ??
        [],
   
  );


}