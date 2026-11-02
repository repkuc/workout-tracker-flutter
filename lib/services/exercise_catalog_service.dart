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

  // Латышские буквы с диакритикой идут сразу после своей основной буквы
  // (a ā b c č … s š t … z ž); остальные символы — по коду.
  static const Map<String, double> _lvLetterRank = {
    'ā': 97.5, 'č': 99.5, 'ē': 101.5, 'ģ': 103.5, 'ī': 105.5, 'ķ': 107.5,
    'ļ': 108.5, 'ņ': 110.5, 'š': 115.5, 'ū': 117.5, 'ž': 122.5,
  };

  // Сравнить названия для сортировки по алфавиту на языке languageCode:
  // по нормализованному названию (регистр, «ё» = «е»); для lv — в латышском
  // порядке букв. Использовать везде, где упражнения сортируются по названию.
  static int compareNames(String a, String b, String languageCode) {
    final x = normalize(a);
    final y = normalize(b);
    if (languageCode != 'lv') return x.compareTo(y);
    final xs = x.runes.toList();
    final ys = y.runes.toList();
    for (var i = 0; i < xs.length && i < ys.length; i++) {
      final rx = _lvLetterRank[String.fromCharCode(xs[i])] ?? xs[i].toDouble();
      final ry = _lvLetterRank[String.fromCharCode(ys[i])] ?? ys[i].toDouble();
      if (rx != ry) return rx.compareTo(ry);
    }
    return xs.length.compareTo(ys.length);
  }

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
