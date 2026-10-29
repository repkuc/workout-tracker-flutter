import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise_template.dart';
import 'custom_exercise_service.dart';
import 'exercise_catalog_service.dart';
import 'exercise_library_service.dart';
import 'program_service.dart';
import 'workout_service.dart';

// Объединение своих упражнений с новыми встроенными.
// Когда в библиотеку добавляют встроенное упражнение, у пользователя уже
// может быть своё с таким же названием («Face pull»). Для каждого ещё не
// проверенного встроенного id ищем свои упражнения с тем же нормализованным
// названием на любом из трёх языков и объединяем их со встроенным так же,
// как «Объединить» в «Моих упражнениях» (встроенное всегда побеждает).
// Проверенные id храним — повторный запуск ничего не меняет.
// Запуск: при старте после ExerciseIdMigration и после импорта бэкапа.
class BuiltinExerciseMerge {
  static const String checkedKey = 'wt.builtin_ids_checked.v1';
  // Сырые копии данных перед первым настоящим объединением — для ручного восстановления
  static const String preWorkoutsKey = 'wt.workouts.pre_builtin_merge.v1';
  static const String preProgramsKey = 'wt.programs.pre_builtin_merge.v1';
  static const String preCustomKey = 'wt.custom_exercises.pre_builtin_merge.v1';

  static const String _workoutsKey = 'wt.workouts.v1';
  static const String _programsKey = 'wt.programs.v1';
  static const String _customKey = 'wt.custom_exercises.v1';

  static final BuiltinExerciseMerge _instance =
      BuiltinExerciseMerge._internal();
  factory BuiltinExerciseMerge() => _instance;
  BuiltinExerciseMerge._internal();

  // Запустить. force — проверить все встроенные, а не только новые
  // (после импорта: в бэкапе могут быть свои дубликаты уже проверенных).
  // Возвращает число объединённых своих упражнений. Никогда не бросает:
  // при ошибке — debugPrint, данные остаются прежними, id не отмечаются.
  Future<int> run({bool force = false}) async {
    SharedPreferences? prefs;
    // Сырые строки до изменений — чтобы откатить, если сохранение сорвётся
    final Map<String, String?> before = {};
    var saving = false;
    try {
      prefs = await SharedPreferences.getInstance();
      final library = ExerciseLibraryService();
      final checked = (prefs.getStringList(checkedKey) ?? const <String>[])
          .toSet();
      final builtIn = await library.getBuiltInExercises();
      final toCheck =
          builtIn.where((t) => force || !checked.contains(t.id)).toList();
      if (toCheck.isEmpty) return 0;

      // Своё упражнение → (встроенное, язык совпавшего названия)
      final custom = await library.getCustomExercises();
      final matches = <String, (ExerciseTemplate, String)>{};
      for (final c in custom) {
        final names = ExerciseCatalogService.namesOf(c);
        for (final b in toCheck) {
          final lang = _matchingLanguage(b, names);
          if (lang != null) {
            matches[c.id] = (b, lang);
            break;
          }
        }
      }

      if (matches.isNotEmpty) {
        for (final key in [_workoutsKey, _programsKey, _customKey]) {
          before[key] = prefs.getString(key);
        }
        await _savePreMergeCopy(prefs);

        final workoutService = WorkoutService();
        final programService = ProgramService();
        final workouts = await workoutService.loadAllWorkouts();
        final programs = await programService.loadAllPrograms();
        // loadAllWorkouts при битом JSON молча отдаёт [] — тогда своё
        // упражнение удалилось бы, а тренировки с его id остались бы
        // без шаблона. Проверяем сырую строку сами (битая — исключение).
        final rawWorkouts = before[_workoutsKey];
        if (rawWorkouts != null &&
            rawWorkouts.isNotEmpty &&
            (json.decode(rawWorkouts) as List).length != workouts.length) {
          throw StateError('workouts could not be read');
        }
        final muscleLabels = <String, Map<String, String>>{};
        var workoutsChanged = false, programsChanged = false;

        for (final entry in matches.entries) {
          final (target, lang) = entry.value;
          // Снимок названия — на языке, на котором пользователь его назвал
          // (при старте перевода приложения ещё нет, текущий язык неизвестен)
          final labels =
              muscleLabels[lang] ??= await _loadMuscleLabels(lang);
          final changed = CustomExerciseService.repointExercises(
            workouts: workouts,
            programs: programs,
            sourceId: entry.key,
            target: target,
            name: target.getName(lang),
            workoutMuscleText: labels[target.muscleGroup],
          );
          workoutsChanged |= changed.workouts;
          programsChanged |= changed.programs;
        }

        // Сохраняем: сначала данные, потом библиотеку (как «Объединить»)
        saving = true;
        if (workoutsChanged) await workoutService.saveAllWorkouts(workouts);
        if (programsChanged) await programService.saveAllPrograms(programs);
        await library.saveCustomExercises(
            custom.where((t) => !matches.containsKey(t.id)).toList());
        saving = false;
        await ExerciseCatalogService().reload();
      }

      await prefs.setStringList(
          checkedKey, {...checked, ...builtIn.map((t) => t.id)}.toList());
      debugPrint('Built-in exercise merge${force ? ' (forced)' : ''}: '
          'checked ${toCheck.length}, merged ${matches.length}'
          '${matches.isEmpty ? '' : ' ${matches.map((k, v) => MapEntry(k, v.$1.id))}'}');
      return matches.length;
    } catch (e) {
      debugPrint('Built-in exercise merge failed: $e');
      if (saving && prefs != null) await _restore(prefs, before);
      return 0;
    }
  }

  // Язык, на котором название встроенного совпало с одним из названий своего
  // (порядок ru → lv → en), или null.
  static String? _matchingLanguage(
      ExerciseTemplate builtIn, Set<String> customNames) {
    for (final lang in const ['ru', 'lv', 'en']) {
      final name = ExerciseCatalogService.normalize(builtIn.getName(lang));
      if (name.isNotEmpty && customNames.contains(name)) return lang;
    }
    return null;
  }

  // Один раз сохранить сырые строки тренировок, программ и своих упражнений
  // (ключ тренировок — последним: по нему проверяем, что копия уже есть).
  Future<void> _savePreMergeCopy(SharedPreferences prefs) async {
    if (prefs.containsKey(preWorkoutsKey)) return;
    await prefs.setString(preCustomKey, prefs.getString(_customKey) ?? '');
    await prefs.setString(preProgramsKey, prefs.getString(_programsKey) ?? '');
    await prefs.setString(preWorkoutsKey, prefs.getString(_workoutsKey) ?? '');
  }

  // Сохранение сорвалось на полпути — вернуть сырые строки как были.
  Future<void> _restore(
      SharedPreferences prefs, Map<String, String?> before) async {
    try {
      for (final entry in before.entries) {
        if (entry.value == null) {
          await prefs.remove(entry.key);
        } else {
          await prefs.setString(entry.key, entry.value!);
        }
      }
      // Каталог — заново из восстановленной библиотеки
      await ExerciseCatalogService().reload();
    } catch (e) {
      debugPrint('Built-in exercise merge restore failed: $e');
    }
  }

  // Подписи групп мышц на одном языке: ключ группы → «Плечи»
  // (как Exercise.targetMuscle, который пишет «Объединить» через .tr()).
  Future<Map<String, String>> _loadMuscleLabels(String lang) async {
    try {
      final data = json.decode(
          await rootBundle.loadString('assets/translations/$lang.json'));
      final section = data['workout'] as Map<String, dynamic>;
      return {
        for (final group in ExerciseLibraryService.validGroups)
          if (section['muscle_$group'] is String)
            group: section['muscle_$group'] as String,
      };
    } catch (_) {
      // Без подписей текст группы просто не меняется (muscleGroup всё равно ставится)
      return {};
    }
  }
}
