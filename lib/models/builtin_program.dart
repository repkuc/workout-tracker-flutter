// Готовая (встроенная) программа из assets/programs/builtin_programs.json.
// Только для просмотра: в SharedPreferences и бэкап не попадает.
// «Добавить в мои программы» делает из неё обычную TrainingProgram-копию
// (см. BuiltinProgramService.addToMyPrograms) — связи с исходником нет.

// Текст на нужном языке; нет или пусто — английский, иначе ''.
String _localized(Map<String, String> texts, String languageCode) {
  final text = texts[languageCode];
  if (text != null && text.trim().isNotEmpty) return text;
  return texts['en'] ?? '';
}

// {"ru": "...", "lv": "...", "en": "..."} → Map<String, String>
Map<String, String> _textsFromJson(dynamic json) => {
      if (json is Map)
        for (final entry in json.entries)
          if (entry.value is String) '${entry.key}': entry.value as String,
    };

// Одно упражнение дня: только id шаблона и план. Название и группа мышц
// берутся из каталога упражнений на текущем языке.
class BuiltinProgramExercise {
  final String templateId;
  final int sets;
  final int? repsMin;
  final int? repsMax;

  const BuiltinProgramExercise({
    required this.templateId,
    required this.sets,
    this.repsMin,
    this.repsMax,
  });

  factory BuiltinProgramExercise.fromJson(Map<String, dynamic> json) =>
      BuiltinProgramExercise(
        templateId: json['templateId'] ?? '',
        sets: (json['sets'] as num?)?.toInt() ?? 3,
        repsMin: (json['repsMin'] as num?)?.toInt(),
        repsMax: (json['repsMax'] as num?)?.toInt(),
      );
}

// Тренировочный день готовой программы.
class BuiltinProgramDay {
  final String id;
  final Map<String, String> names;
  final List<BuiltinProgramExercise> exercises;

  const BuiltinProgramDay({
    required this.id,
    required this.names,
    required this.exercises,
  });

  String name(String languageCode) => _localized(names, languageCode);

  factory BuiltinProgramDay.fromJson(Map<String, dynamic> json) =>
      BuiltinProgramDay(
        id: json['id'] ?? '',
        names: _textsFromJson(json['name']),
        exercises: ((json['exercises'] as List?) ?? [])
            .map((e) => BuiltinProgramExercise.fromJson(e))
            .toList(),
      );
}

// Готовая программа целиком.
class BuiltinProgram {
  final String id;
  final Map<String, String> names;
  final Map<String, String> descriptions;
  // Дни недели: 1 = Пн … 7 = Вс, по возрастанию
  final List<int> scheduleDays;
  final List<BuiltinProgramDay> days;

  const BuiltinProgram({
    required this.id,
    required this.names,
    required this.descriptions,
    required this.scheduleDays,
    required this.days,
  });

  String name(String languageCode) => _localized(names, languageCode);
  String description(String languageCode) =>
      _localized(descriptions, languageCode);

  // Всего упражнений во всех днях (для карточки в списке)
  int get exerciseCount =>
      days.fold(0, (sum, day) => sum + day.exercises.length);

  factory BuiltinProgram.fromJson(Map<String, dynamic> json) => BuiltinProgram(
        id: json['id'] ?? '',
        names: _textsFromJson(json['name']),
        descriptions: _textsFromJson(json['description']),
        // Как в TrainingProgram.fromJson: только 1…7, без повторов, по возрастанию
        scheduleDays: ((json['scheduleDays'] as List?) ?? [])
            .map((d) => (d as num).toInt())
            .where((d) => d >= 1 && d <= 7)
            .toSet()
            .toList()
          ..sort(),
        days: ((json['days'] as List?) ?? [])
            .map((d) => BuiltinProgramDay.fromJson(d))
            .toList(),
      );
}
