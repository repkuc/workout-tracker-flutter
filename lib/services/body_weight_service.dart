import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/body_weight_entry.dart';

class BodyWeightService {
  // Ключ под которым храним список в SharedPreferences
  // Думай об этом как об имени ящика в шкафу, где мы храним все записи веса
  static const String _key = 'body_weight_entries';

  // Сохранение новой записи веса
  Future<void> saveEntry(double weight) async {
    // Получаем сегодняшнюю дату в формате "2024-03-15"
    final today = DateTime.now();
    final date = '${today.year}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    // Создаем новую запись веса
    final newEntry = BodyWeightEntry(date: date, weight: weight);

    // Получаем текущий список записей из SharedPreferences
    final entries = await getAllEntries();

    // Если запись на сегодня уже есть — заменяем её
    // Если нет — добавляем новую
    final index = entries.indexWhere((e) => e.date == date);
    if (index >= 0) {
      entries[index] = newEntry; // Заменяем существующую запись
    } else {
      entries.add(newEntry); // Добавляем новую запись
    }

    // Сортируем по дате чтобы график был правильным
    entries.sort((a, b) => a.date.compareTo(b.date));

    // Сохраняем обновленный список обратно в SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final jsonList = entries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  // Получение всех записей веса
  Future<List<BodyWeightEntry>> getAllEntries() async {
    final prefs = await SharedPreferences.getInstance();
    // Получаем список строк из SharedPreferences, каждая строка - это JSON с данными веса
    final jsonList = prefs.getStringList(_key) ?? [];
    // Превращаем каждую строку обратно в объект BodyWeightEntry
    return jsonList
        .map((s) => BodyWeightEntry.fromJson(jsonDecode(s)))
        .toList();
  }

  // Получить записи за последние N дней (для фильтров графика)
  Future<List<BodyWeightEntry>> getEntriesForDays(int days) async {
    final all = await getAllEntries();
    // Вычисляем дату, которая была N дней назад
    final cutoff = DateTime.now().subtract(Duration(days: days));
    // Превращаем эту дату в строку в формате "2024-03-15" для сравнения с датами в записях
    final cutoffStr = '${cutoff.year}-'
        '${cutoff.month.toString().padLeft(2, '0')}-'
        '${cutoff.day.toString().padLeft(2, '0')}';

  // Оставляем только те записи которые новее cutoff
    return all.where((e) => e.date.compareTo(cutoffStr) >= 0).toList();
  }

  // Получить запись за сегодня (чтобы знать записал ли уже)
  Future<BodyWeightEntry?> getTodayEntry() async {
    final today = DateTime.now();
    final date = '${today.year}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final all = await getAllEntries();
    try {
      return all.firstWhere((e) => e.date == date);
    } catch (_) {
      return null; // Если записи на сегодня нет, возвращаем null
    }
  }

 
}