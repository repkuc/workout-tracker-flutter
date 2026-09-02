// Подключаем библиотеку для работы с JSON.
import 'dart:convert';

// Подключаем SharedPreferences — хранилище на телефоне.
import 'package:shared_preferences/shared_preferences.dart';

// Подключаем нашу модель замеров.
import '../models/body_measurement_entry.dart';

// Сервис для работы с замерами тела — загрузка, сохранение, удаление.
// Структура полностью повторяет BodyWeightService для единообразия.
class BodyMeasurementService {
  // Ключ под которым все записи замеров хранятся в SharedPreferences.
  static const String _measurementsKey = 'wt.bodyMeasurements.v1';

  // Singleton — один экземпляр на всё приложение.
  static final BodyMeasurementService _instance = BodyMeasurementService._internal();
  factory BodyMeasurementService() => _instance;
  BodyMeasurementService._internal();

  // Загрузить все записи замеров, отсортированные от новых к старым.
  Future<List<BodyMeasurementEntry>> loadAllEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_measurementsKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    final List<dynamic> jsonList = json.decode(jsonString);
    final entries = jsonList.map((e) => BodyMeasurementEntry.fromJson(e)).toList();

    // Сортируем по дате — новые записи сверху.
    entries.sort((a, b) => b.date.compareTo(a.date));

    return entries;
  }

  // Сохранить весь список записей обратно в хранилище.
  Future<void> _saveAllEntries(List<BodyMeasurementEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_measurementsKey, jsonString);
  }

  // Сохранить (или обновить) запись замеров на конкретную дату.
  // Если на эту дату уже есть запись — она будет заменена, а не задублирована.
  // Это позволяет пользователю дозаполнить недостающие замеры позже в тот же день.
  Future<void> saveEntry(BodyMeasurementEntry entry) async {
    final entries = await loadAllEntries();

    // Ищем существующую запись на эту же дату.
    final existingIndex = entries.indexWhere((e) => e.date == entry.date);

    if (existingIndex != -1) {
      // Заменяем существующую запись новой.
      entries[existingIndex] = entry;
    } else {
      // Добавляем новую запись.
      entries.add(entry);
    }

    await _saveAllEntries(entries);
  }

  // Получить запись за сегодняшний день, если она есть.
  // Используется чтобы при открытии формы добавления сразу показать
  // уже введённые сегодня значения (если пользователь возвращается дополнить).
  Future<BodyMeasurementEntry?> getTodayEntry() async {
    final today = _getTodayDate();
    final entries = await loadAllEntries();

    try {
      return entries.firstWhere((e) => e.date == today);
    } catch (e) {
      return null;
    }
  }

  // Удалить запись по дате.
  Future<void> deleteEntry(String date) async {
    final entries = await loadAllEntries();
    entries.removeWhere((e) => e.date == date);
    await _saveAllEntries(entries);
  }

  // Получить сегодняшнюю дату в формате YYYY-MM-DD.
  String _getTodayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}