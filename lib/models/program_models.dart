// Подключаем библиотеку Dart для работы с JSON: jsonEncode/jsonDecode.
// В этом файле напрямую она не используется, но может быть нужна соседнему коду при работе с этими моделями.
import 'dart:convert';

// Модель одного упражнения внутри тренировочного дня программы.
// Это именно шаблон упражнения: здесь нет фактического веса, повторений и выполненных подходов.
class ProgramExercise {
  // Название упражнения, например "Жим лежа" или "Приседания".
  String name;

  // Целевая мышечная группа, например "Грудь", "Спина", "Ноги".
  String targetMuscle;

  // Планируемое количество подходов для этого упражнения.
  int targetSets;

  // Конструктор создает объект ProgramExercise и заполняет его поля.
  ProgramExercise({
    // required означает, что name обязательно нужно передать при создании объекта.
    required this.name,

    // Если targetMuscle не передали, по умолчанию будет пустая строка.
    this.targetMuscle = '',

    // Если targetSets не передали, по умолчанию будет 3 подхода.
    this.targetSets = 3,
  });

  // Метод превращает объект ProgramExercise в Map, чтобы его можно было сохранить как JSON.
  Map<String, dynamic> toJson() => {
    // Ключ 'name' в JSON получит значение из поля name.
    'name': name,

    // Ключ 'targetMuscle' в JSON получит значение из поля targetMuscle.
    'targetMuscle': targetMuscle,

    // Ключ 'targetSets' в JSON получит значение из поля targetSets.
    'targetSets': targetSets,
  };

  // Фабричный конструктор создает ProgramExercise из Map, например после чтения JSON.
  factory ProgramExercise.fromJson(Map<String, dynamic> json) => ProgramExercise(
    // Берем значение по ключу 'name'; если его нет или там null, используем пустую строку.
    name: json['name'] ?? '',

    // Берем значение по ключу 'targetMuscle'; если его нет или там null, используем пустую строку.
    targetMuscle: json['targetMuscle'] ?? '',

    // Берем значение по ключу 'targetSets'; если его нет или там null, используем 3.
    targetSets: json['targetSets'] ?? 3,
  );
}

// Модель одного тренировочного дня внутри программы.
// Например, это может быть "День 1: Грудь" со списком упражнений.
class ProgramWorkout {
  // Уникальный идентификатор тренировки, чтобы отличать ее от других.
  String id;

  // Название тренировочного дня, например "День 1: Грудь".
  String name;

  // Дополнительное описание тренировки, если нужно что-то пояснить пользователю.
  String description;

  // Список упражнений, которые входят в эту тренировку.
  List<ProgramExercise> exercises;

  // Конструктор создает объект ProgramWorkout и заполняет его поля.
  ProgramWorkout({
    // id обязателен, потому что каждая тренировка должна иметь свой идентификатор.
    required this.id,

    // name обязателен, потому что тренировке нужно отображаемое название.
    required this.name,

    // Если description не передали, описание будет пустым.
    this.description = '',

    // exercises можно не передавать; ниже тогда будет создан пустой список.
    List<ProgramExercise>? exercises,
  }) : exercises = exercises ?? [];
  // Часть после двоеточия называется initializer list.
  // Здесь она говорит: если exercises равен null, запиши в поле пустой список.

  // Метод превращает объект ProgramWorkout в Map для сохранения в JSON.
  Map<String, dynamic> toJson() => {
    // Сохраняем id тренировки.
    'id': id,

    // Сохраняем название тренировки.
    'name': name,

    // Сохраняем описание тренировки.
    'description': description,

    // Превращаем каждое упражнение в Map и затем собираем результат обратно в List.
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  // Фабричный конструктор создает ProgramWorkout из Map, например после чтения JSON.
  factory ProgramWorkout.fromJson(Map<String, dynamic> json) => ProgramWorkout(
    // Берем id из JSON; здесь запасного значения нет, поэтому ожидается, что id существует.
    id: json['id'],

    // Берем name из JSON; если значения нет, используем пустую строку.
    name: json['name'] ?? '',

    // Берем description из JSON; если значения нет, используем пустую строку.
    description: json['description'] ?? '',

    // Берем список exercises из JSON и приводим его к List?, потому что список может отсутствовать.
    exercises: (json['exercises'] as List?)
        // ?. означает: выполняй map только если список не равен null.
        ?.map((e) => ProgramExercise.fromJson(e))
        // Превращаем результат map обратно в обычный List.
        .toList() ?? [],
        // ?? [] означает: если exercises был null, используй пустой список.
  );
}

// Модель целой тренировочной программы.
// Она содержит общую информацию и список тренировочных дней.
class TrainingProgram {
  // Уникальный идентификатор программы.
  String id;

  // Название программы, например "Сила 3 раза в неделю".
  String name;

  // Описание программы: цель, уровень сложности, примечания.
  String description;

  // Текстовое расписание, например "Пн/Ср/Пт".
  String schedule;

  // Список тренировок, которые входят в программу.
  List<ProgramWorkout> workouts;

  // Флаг показывает, пользовательская ли это программа.
  bool isCustom;

  // Конструктор создает объект TrainingProgram и заполняет его поля.
  TrainingProgram({
    // id обязателен, чтобы программу можно было надежно найти или обновить.
    required this.id,

    // name обязателен, потому что программу нужно показывать пользователю по названию.
    required this.name,

    // Если description не передали, описание будет пустым.
    this.description = '',

    // Если schedule не передали, расписание будет пустым.
    this.schedule = '',

    // workouts можно не передавать; ниже тогда будет создан пустой список.
    List<ProgramWorkout>? workouts,

    // По умолчанию считаем программу пользовательской.
    this.isCustom = true,
  }) : workouts = workouts ?? [];
  // Если workouts равен null, initializer list запишет в поле пустой список.

  // Метод превращает TrainingProgram в Map для дальнейшего сохранения как JSON.
  Map<String, dynamic> toJson() => {
    // Сохраняем id программы.
    'id': id,

    // Сохраняем название программы.
    'name': name,

    // Сохраняем описание программы.
    'description': description,

    // Сохраняем расписание программы.
    'schedule': schedule,

    // Превращаем каждую тренировку в Map и собираем все тренировки в List.
    'workouts': workouts.map((w) => w.toJson()).toList(),

    // Сохраняем флаг пользовательской программы.
    'isCustom': isCustom,
  };

  // Фабричный конструктор создает TrainingProgram из Map, например после чтения JSON.
  factory TrainingProgram.fromJson(Map<String, dynamic> json) => TrainingProgram(
    // Берем id из JSON; здесь ожидается, что id существует.
    id: json['id'],

    // Берем name из JSON; если значения нет, используем пустую строку.
    name: json['name'] ?? '',

    // Берем description из JSON; если значения нет, используем пустую строку.
    description: json['description'] ?? '',

    // Берем schedule из JSON; если значения нет, используем пустую строку.
    schedule: json['schedule'] ?? '',

    // Берем список workouts из JSON и приводим его к List?, потому что он может отсутствовать.
    workouts: (json['workouts'] as List?)
        // Если workouts не null, превращаем каждый элемент JSON в ProgramWorkout.
        ?.map((w) => ProgramWorkout.fromJson(w))
        // Превращаем результат map обратно в обычный List.
        .toList() ?? [],
        // Если workouts был null, вместо него используем пустой список.

    // Берем isCustom из JSON; если значения нет, считаем программу пользовательской.
    isCustom: json['isCustom'] ?? true,
  );
}
