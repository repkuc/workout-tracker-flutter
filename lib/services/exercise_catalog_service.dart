import '../models/exercise_template.dart';
import 'exercise_library_service.dart';

// Каталог упражнений в памяти: по id шаблона и по названию.
// Нужен, чтобы узнавать упражнение по id (а у старых данных — по названию
// на любом из трёх языков) и показывать встроенные упражнения на текущем языке.
// init() ждём в main.dart, после изменения пользовательской базы — reload().
class ExerciseCatalogService {
  static final ExerciseCatalogService _instance =
      ExerciseCatalogService._internal();
  factory ExerciseCatalogService() => _instance;
  ExerciseCatalogService._internal();

  // id → шаблон (встроенные и пользовательские)
  final Map<String, ExerciseTemplate> _byId = {};
  // нормализованное название → id; встроенные важнее пользовательских
  final Map<String, String> _idByName = {};
  // нормализованные названия встроенных упражнений на всех языках
  final Set<String> _builtInNames = {};
  Future<void>? _loading;

  // Загрузить каталог один раз (повторный вызов возвращает тот же Future).
  Future<void> init() => _loading ??= _load();

  // Перечитать каталог (после добавления / импорта пользовательских упражнений).
  Future<void> reload() => _loading = _load();

  Future<void> _load() async {
    final library = ExerciseLibraryService();
    final builtIn = await library.getBuiltInExercises();
    final custom = await library.getCustomExercises();

    _byId.clear();
    _idByName.clear();
    _builtInNames.clear();

    // Сначала встроенные — при совпадении названий они выигрывают
    for (final template in builtIn) {
      _byId[template.id] = template;
      for (final key in namesOf(template)) {
        _builtInNames.add(key);
        _idByName.putIfAbsent(key, () => template.id);
      }
    }
    for (final template in custom) {
      _byId.putIfAbsent(template.id, () => template);
      for (final key in namesOf(template)) {
        _idByName.putIfAbsent(key, () => template.id);
      }
    }
  }

  // Нормализация названия: обрезать края, сжать пробелы внутри,
  // нижний регистр, «ё» → «е». Опечатки и другие формулировки не угадываем.
  static String normalize(String name) => name
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase()
      .replaceAll('ё', 'е');

  // Нормализованные названия шаблона на всех трёх языках (без пустых)
  static Set<String> namesOf(ExerciseTemplate template) => {
        for (final name in [template.nameRu, template.nameLv, template.nameEn])
          if (normalize(name).isNotEmpty) normalize(name),
      };

  ExerciseTemplate? templateById(String? id) => id == null ? null : _byId[id];

  // id шаблона по названию на любом языке или null
  String? idForName(String name) => _idByName[normalize(name)];

  // Пользовательское упражнение, которое называется как встроенное
  // (дубликаты от старой миграции) — в списке выбора его не показываем.
  bool isBuiltInDuplicate(ExerciseTemplate template) =>
      template.isCustom && namesOf(template).any(_builtInNames.contains);

  // Название для показа: встроенное — на текущем языке, пользовательское —
  // своё, не найденное в каталоге — сохранённое в тренировке.
  String displayName({
    String? templateId,
    required String name,
    required String languageCode,
  }) {
    final template = templateById(templateId);
    if (template == null) return name;
    final localized = template.getName(languageCode);
    return localized.trim().isEmpty ? name : localized;
  }

  // Ключ «одного и того же упражнения» для статистики и «Повторить»:
  // id шаблона, иначе id по названию, иначе 'name:<нормализованное название>'.
  String identityKey({String? templateId, required String name}) =>
      templateId ?? idForName(name) ?? 'name:${normalize(name)}';
}
