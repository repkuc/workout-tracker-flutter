// Подключаем библиотеку для работы с JSON: jsonEncode превращает объект в строку,
// jsonDecode превращает строку обратно в объект.
import 'dart:convert';

// Подключаем SharedPreferences — это встроенное хранилище ключ-значение на телефоне,
// куда мы сохраняем все данные приложения (так же как для тренировок).
import 'package:shared_preferences/shared_preferences.dart';

// Подключаем библиотеку для генерации уникальных ID (UUID).
import 'package:uuid/uuid.dart';

// Подключаем модели которые мы только что создали.
import '../models/program_models.dart';

// Сервис для работы с программами тренировок.
// Отвечает за сохранение, загрузку, создание и удаление программ.
class ProgramService {
  // Ключ под которым все программы хранятся в SharedPreferences.
  // Версия "v1" в конце — на случай если в будущем поменяется формат данных,
  // можно будет завести "v2" не потеряв старые данные.
  static const String _programsKey = 'wt.programs.v1';

  // Генератор уникальных идентификаторов.
  final _uuid = const Uuid();

  // Singleton паттерн — во всём приложении существует только один экземпляр
  // ProgramService, а не создаётся новый при каждом вызове ProgramService().
  static final ProgramService _instance = ProgramService._internal();
  factory ProgramService() => _instance;
  ProgramService._internal();

  // Загрузить все программы из SharedPreferences.
  Future<List<TrainingProgram>> loadAllPrograms() async {
    // Получаем доступ к хранилищу.
    final prefs = await SharedPreferences.getInstance();

    // Пытаемся достать сохранённую строку JSON по нашему ключу.
    final jsonString = prefs.getString(_programsKey);

    // Если ничего не сохранено — возвращаем пустой список, программ ещё нет.
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    // Превращаем строку JSON обратно в список объектов Dart (List<dynamic>).
    final List<dynamic> jsonList = json.decode(jsonString);

    // Для каждого элемента списка создаём объект TrainingProgram через fromJson,
    // и собираем всё обратно в List<TrainingProgram>.
    return jsonList.map((e) => TrainingProgram.fromJson(e)).toList();
  }

  // Сохранить весь список программ обратно в SharedPreferences.
  Future<void> saveAllPrograms(List<TrainingProgram> programs) async {
    final prefs = await SharedPreferences.getInstance();

    // Превращаем каждую программу в Map через toJson, собираем в список,
    // а затем весь список кодируем в одну JSON строку.
    final jsonString = json.encode(programs.map((p) => p.toJson()).toList());

    // Сохраняем получившуюся строку в хранилище.
    await prefs.setString(_programsKey, jsonString);
  }

  // Получить одну программу по её ID.
  Future<TrainingProgram?> getProgram(String id) async {
    final programs = await loadAllPrograms();

    // firstWhere ищет первый элемент удовлетворяющий условию.
    // Если ничего не найдено — вернётся null благодаря orElse.
    try {
      return programs.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  // Создать новую программу и сразу сохранить её.
  Future<TrainingProgram> createProgram({
    required String name,
    String description = '',
    String schedule = '',
  }) async {
    // Создаём объект новой программы с уникальным ID.
    final program = TrainingProgram(
      id: _uuid.v4(),
      name: name,
      description: description,
      schedule: schedule,
      isCustom: true,
    );

    // Загружаем текущий список, добавляем новую программу, сохраняем весь список обратно.
    final programs = await loadAllPrograms();
    programs.add(program);
    await saveAllPrograms(programs);

    // Возвращаем созданную программу, чтобы можно было сразу с ней работать
    // (например открыть экран редактирования).
    return program;
  }

  // Удалить программу по ID.
  Future<bool> deleteProgram(String id) async {
    final programs = await loadAllPrograms();

    // removeWhere удаляет из списка все элементы удовлетворяющие условию.
    final lengthBefore = programs.length;
    programs.removeWhere((p) => p.id == id);

    // Если длина списка не изменилась — значит программа с таким ID не найдена.
    if (programs.length == lengthBefore) return false;

    await saveAllPrograms(programs);
    return true;
  }

  // Добавить новый тренировочный день в существующую программу.
  Future<bool> addWorkoutToProgram(String programId, ProgramWorkout workout) async {
    final programs = await loadAllPrograms();

    // Ищем индекс нужной программы в списке.
    final index = programs.indexWhere((p) => p.id == programId);
    if (index == -1) return false;

    // Добавляем новый день тренировки в список тренировок этой программы.
    programs[index].workouts.add(workout);

    await saveAllPrograms(programs);
    return true;
  }

  // Удалить тренировочный день из программы.
  Future<bool> removeWorkoutFromProgram(String programId, String workoutId) async {
    final programs = await loadAllPrograms();

    final index = programs.indexWhere((p) => p.id == programId);
    if (index == -1) return false;

    programs[index].workouts.removeWhere((w) => w.id == workoutId);

    await saveAllPrograms(programs);
    return true;
  }

  // Обновить основную информацию о программе (название, описание, расписание).
  Future<bool> updateProgramMeta(
    String programId, {
    String? name,
    String? description,
    String? schedule,
  }) async {
    final programs = await loadAllPrograms();

    final index = programs.indexWhere((p) => p.id == programId);
    if (index == -1) return false;

    // Обновляем только те поля, которые реально передали (не null).
    if (name != null) programs[index].name = name;
    if (description != null) programs[index].description = description;
    if (schedule != null) programs[index].schedule = schedule;

    await saveAllPrograms(programs);
    return true;
  }
}
