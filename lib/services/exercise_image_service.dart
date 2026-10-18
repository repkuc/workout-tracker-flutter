import 'package:flutter/services.dart';
import '../models/exercise_template.dart';
import 'exercise_library_service.dart';

// Демо-картинки упражнений (free-exercise-db, public domain).
// Для каждого встроенного упражнения в assets/exercise_images/ лежат два кадра:
// <id>_0.webp (начальное положение) и <id>_1.webp (конечное).
// В тренировках упражнение хранится только по названию (на любом из трёх языков),
// поэтому ищем шаблон сначала по id, потом по названию.
class ExerciseImageService {
  static const String _folder = 'assets/exercise_images';

  static final ExerciseImageService _instance = ExerciseImageService._internal();
  factory ExerciseImageService() => _instance;
  ExerciseImageService._internal();

  // id → шаблон, только для упражнений, у которых есть оба кадра
  final Map<String, ExerciseTemplate> _byId = {};
  // название (обрезанное, в нижнем регистре, на любом языке) → шаблон
  final Map<String, ExerciseTemplate> _byName = {};
  Future<void>? _loading;
  bool _loaded = false;

  // true, когда init() завершился (обычно ещё в main до запуска UI)
  bool get isLoaded => _loaded;

  // Загрузить встроенные упражнения и список картинок. Повторный вызов
  // возвращает тот же Future, поэтому звать можно сколько угодно раз.
  Future<void> init() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final builtIn = await ExerciseLibraryService().getBuiltInExercises();
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets().toSet();

      for (final template in builtIn) {
        final paths = _pathsForId(template.id);
        // Кнопку показываем только если в сборке есть оба кадра
        if (!assets.contains(paths[0]) || !assets.contains(paths[1])) continue;
        _byId[template.id] = template;
        for (final name in [template.nameRu, template.nameLv, template.nameEn]) {
          final key = _normalize(name);
          if (key.isNotEmpty) _byName.putIfAbsent(key, () => template);
        }
      }
    } catch (_) {
      // Без картинок приложение работает как раньше — просто без кнопки ⓘ
    }
    _loaded = true;
  }

  static String _normalize(String name) => name.trim().toLowerCase();

  static List<String> _pathsForId(String id) =>
      ['$_folder/${id}_0.webp', '$_folder/${id}_1.webp'];

  // Найти встроенный шаблон с картинками: сначала по id, потом по названию.
  // Для пользовательских упражнений возвращает null.
  ExerciseTemplate? findTemplate({String? id, String? name}) {
    if (id != null && _byId.containsKey(id)) return _byId[id];
    if (name != null) return _byName[_normalize(name)];
    return null;
  }

  // Два пути к кадрам [начало, конец] или null, если картинок нет.
  List<String>? imagePaths({String? id, String? name}) {
    final template = findTemplate(id: id, name: name);
    return template == null ? null : _pathsForId(template.id);
  }
}
