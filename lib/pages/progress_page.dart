import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/body_weight_service.dart';
import '../models/body_weight_entry.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  _ProgressPageState createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  // Наш сервис для работы с весом тела
  final _bodyWeightService = BodyWeightService();

  // Выбранный период фильтра (по умолчанию 30 дней)
  // null означает "всё время"
  int? _selectedDays = 30;

  // Записи веса тела — пока пустой список, загрузим позже
  List<BodyWeightEntry> _weightEntries = [];

  // Флаг загрузки — пока грузим данные показываем индикатор загрузки
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData(); // Загружаем данные при инициализации страницы
  }

  // Метод для загрузки данных из сервиса
  Future<void> _loadData() async {
    // Говорим Flutter "начинаем загрузку"
    setState(() {
      _isLoading = true;
    });

    // Загружаем записи веса в зависимости от фильтра
    final weightEntries = _selectedDays == null
        ? await _bodyWeightService.getAllEntries() // Все записи
        : await _bodyWeightService
            .getEntriesForDays(_selectedDays!); // Записи за последние N дней

    // Говорим Flutter "загрузка закончилась, обновляем данные"
    setState(() {
      _weightEntries = weightEntries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF111827),
        appBar: AppBar(
          title: const Text('progress.title').tr(),
        ),
        body: _isLoading
            // Пока грузим — показываем спиннер по центру
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFF97316),
                ),
              )
            // Загрузили — показываем контент
            : Column(
                children: [
                  // Фильтры периода (7д / 30д / Год / Всё)
                  _buildFilters(),

                  // Основной контент — скроллируемый список с графиками
                  Expanded(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Сюда будем добавлять карточки с графиками
                              // Пока просто заглушка
                              Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1F2937),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: const Text(
                                    'progress.placeholder',
                                    style: TextStyle(color: Colors.grey),
                                  ).tr(),
                                ),
                              )
                            ],
                          )))
                ],
              ));
  }

// Виджет с кнопками фильтра периода
  Widget _buildFilters() {
    // Список вариантов: [название, значение в днях или null]
    final filters = [
      ('progress.filter_7d'.tr(), 7),
      ('progress.filter_30d'.tr(), 30),
      ('progress.filter_year'.tr(), 365),
      ('progress.filter_all'.tr(), null),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: filters.map((filter) {
          final label = filter.$1; // название кнопки
          final days = filter.$2; // значение в днях
          final isActive = _selectedDays == days;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                // При нажатии меняем фильтр и перезагружаем данные
                setState(() => _selectedDays = days);
                _loadData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFF97316) // оранжевый если активный
                      : const Color(0xFF374151), // серый если неактивный
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey[400],
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
