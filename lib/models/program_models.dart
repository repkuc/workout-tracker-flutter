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

  // id шаблона из библиотеки упражнений. null — ещё не привязано,
  // тогда упражнение узнаём по name.
  String? templateId;

  // Планируемое количество подходов для этого упражнения.
  int targetSets;

  // План повторов «от — до» (например 8–12). null — плана повторов нет.
  // Правило: оба null, либо 1 ≤ repsMin ≤ repsMax ≤ 100 (см. normalizeRepsRange).
  int? repsMin;
  int? repsMax;

  // Конструктор создает объект ProgramExercise и заполняет его поля.
  ProgramExercise({
    // required означает, что name обязательно нужно передать при создании объекта.
    required this.name,

    // Если targetMuscle не передали, по умолчанию будет пустая строка.
    this.targetMuscle = '',

    // id шаблона необязателен (в старых данных его нет).
    this.templateId,

    // Если targetSets не передали, по умолчанию будет 3 подхода.
    this.targetSets = 3,

    // По умолчанию плана повторов нет.
    this.repsMin,
    this.repsMax,
  });

  // Копия упражнения — чтобы диалог дня мог менять план повторов,
  // не трогая исходный объект, пока пользователь не нажал «Сохранить».
  ProgramExercise copy() => ProgramExercise(
    name: name,
    targetMuscle: targetMuscle,
    templateId: templateId,
    targetSets: targetSets,
    repsMin: repsMin,
    repsMax: repsMax,
  );

  // Привести план повторов к правилу: значения 1…100 (0 и меньше — «нет плана»),
  // если заполнено только одно — берём его для обоих, «от» не больше «до».
  void normalizeRepsRange() {
    int? clean(int? v) => (v == null || v < 1) ? null : (v > 100 ? 100 : v);
    var min = clean(repsMin);
    var max = clean(repsMax);
    min ??= max;
    max ??= min;
    if (min != null && max != null && min > max) max = min;
    repsMin = min;
    repsMax = max;
  }

  // Текст плана повторов: «8–12», «10» (если от = до) или null, если плана нет.
  String? get repsRangeText {
    if (repsMin == null || repsMax == null) return null;
    return repsMin == repsMax ? '$repsMin' : '$repsMin–$repsMax';
  }

  // Метод превращает объект ProgramExercise в Map, чтобы его можно было сохранить как JSON.
  Map<String, dynamic> toJson() => {
    // Ключ 'name' в JSON получит значение из поля name.
    'name': name,

    // Ключ 'targetMuscle' в JSON получит значение из поля targetMuscle.
    'targetMuscle': targetMuscle,

    // id шаблона; null тоже сохраняем — старые версии приложения его игнорируют.
    'templateId': templateId,

    // Ключ 'targetSets' в JSON получит значение из поля targetSets.
    'targetSets': targetSets,

    // План повторов; null тоже сохраняем — старые версии приложения его просто игнорируют.
    'repsMin': repsMin,
    'repsMax': repsMax,
  };

  // Фабричный конструктор создает ProgramExercise из Map, например после чтения JSON.
  factory ProgramExercise.fromJson(Map<String, dynamic> json) => ProgramExercise(
    // Берем значение по ключу 'name'; если его нет или там null, используем пустую строку.
    name: json['name'] ?? '',

    // Берем значение по ключу 'targetMuscle'; если его нет или там null, используем пустую строку.
    targetMuscle: json['targetMuscle'] ?? '',

    // В старых данных id шаблона нет — будет null (заполняет миграция).
    templateId: json['templateId'],

    // Берем значение по ключу 'targetSets'; если его нет или там null, используем 3.
    targetSets: json['targetSets'] ?? 3,

    // В старых данных плана повторов нет — будет null.
    repsMin: (json['repsMin'] as num?)?.toInt(),
    repsMax: (json['repsMax'] as num?)?.toInt(),
  )..normalizeRepsRange();
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

  // Описание программы (многострочное): рекомендации, как подбирать вес и т.п.
  String description;

  // Дни недели тренировок: 1 = Пн … 7 = Вс, по возрастанию. Пусто — дни не выбраны.
  // Раньше расписание было свободным текстом (поле 'schedule') — при чтении
  // старых данных он переносится в начало описания (см. fromJson).
  List<int> scheduleDays;

  // Список тренировок, которые входят в программу.
  List<ProgramWorkout> workouts;

  // Флаг показывает, пользовательская ли это программа.
  bool isCustom;

  // Когда программа создана (мс с эпохи). Ставится только при создании
  // (вручную или копией готовой), правка не меняет. У старых программ null.
  // Нужен для сортировки «Моих» программ по свежести.
  int? createdAt;

  // Конструктор создает объект TrainingProgram и заполняет его поля.
  TrainingProgram({
    // id обязателен, чтобы программу можно было надежно найти или обновить.
    required this.id,

    // name обязателен, потому что программу нужно показывать пользователю по названию.
    required this.name,

    // Если description не передали, описание будет пустым.
    this.description = '',

    // Дни недели можно не передавать — тогда пустой список.
    List<int>? scheduleDays,

    // workouts можно не передавать; ниже тогда будет создан пустой список.
    List<ProgramWorkout>? workouts,

    // По умолчанию считаем программу пользовательской.
    this.isCustom = true,

    // Время создания необязательно (в старых данных его нет).
    this.createdAt,
  })  : scheduleDays = scheduleDays ?? [],
        workouts = workouts ?? [];
  // Если workouts равен null, initializer list запишет в поле пустой список.

  // Метод превращает TrainingProgram в Map для дальнейшего сохранения как JSON.
  Map<String, dynamic> toJson() => {
    // Сохраняем id программы.
    'id': id,

    // Сохраняем название программы.
    'name': name,

    // Сохраняем описание программы.
    'description': description,

    // Сохраняем дни недели. Старое текстовое 'schedule' больше не пишем.
    'scheduleDays': scheduleDays,

    // Превращаем каждую тренировку в Map и собираем все тренировки в List.
    'workouts': workouts.map((w) => w.toJson()).toList(),

    // Сохраняем флаг пользовательской программы.
    'isCustom': isCustom,

    // Время создания; null тоже сохраняем — старые версии приложения его игнорируют.
    'createdAt': createdAt,
  };

  // Фабричный конструктор создает TrainingProgram из Map, например после чтения JSON.
  factory TrainingProgram.fromJson(Map<String, dynamic> json) => TrainingProgram(
    // Берем id из JSON; здесь ожидается, что id существует.
    id: json['id'],

    // Берем name из JSON; если значения нет, используем пустую строку.
    name: json['name'] ?? '',

    // Описание + перенос старого текстового расписания (см. _migrateDescription).
    description: _migrateDescription(
      json['schedule'] as String?,
      json['description'] as String? ?? '',
    ),

    // Дни недели: только 1…7, без повторов, по возрастанию. В старых данных их нет.
    scheduleDays: ((json['scheduleDays'] as List?) ?? [])
        .map((d) => (d as num).toInt())
        .where((d) => d >= 1 && d <= 7)
        .toSet()
        .toList()
      ..sort(),

    // Берем список workouts из JSON и приводим его к List?, потому что он может отсутствовать.
    workouts: (json['workouts'] as List?)
        // Если workouts не null, превращаем каждый элемент JSON в ProgramWorkout.
        ?.map((w) => ProgramWorkout.fromJson(w))
        // Превращаем результат map обратно в обычный List.
        .toList() ?? [],
        // Если workouts был null, вместо него используем пустой список.

    // Берем isCustom из JSON; если значения нет, считаем программу пользовательской.
    isCustom: json['isCustom'] ?? true,

    // В старых данных и бэкапах времени создания нет — будет null.
    createdAt: (json['createdAt'] as num?)?.toInt(),
  );

  // Миграция старого текстового расписания: если оно было ("Пн/Ср/Пт"),
  // ставим его в начало описания (дальше пустая строка и старое описание),
  // чтобы ничего не потерялось. Новые данные поле 'schedule' не пишут,
  // поэтому миграция срабатывает один раз и при повторном чтении ничего не меняет.
  // Работает и для программ из старых бэкапов — импорт тоже идёт через fromJson.
  static String _migrateDescription(String? oldSchedule, String description) {
    final schedule = oldSchedule?.trim() ?? '';
    if (schedule.isEmpty) return description;
    if (description.trim().isEmpty) return schedule;
    return '$schedule\n\n$description';
  }
}
