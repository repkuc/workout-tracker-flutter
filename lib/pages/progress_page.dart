import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/body_weight_service.dart';
import '../models/body_weight_entry.dart';
import '../widgets/volume_chart_card.dart';
import '../widgets/exercise_progress_card.dart';
import '../widgets/body_weight_chart_card.dart';

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
  BodyWeightEntry? _todayWeight; // запись веса за сегодня

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

    final todayWeight =
        await _bodyWeightService.getTodayEntry(); // Запись веса за сегодня
    // Говорим Flutter "загрузка закончилась, обновляем данные"
    setState(() {
      _weightEntries = weightEntries;
      _todayWeight = todayWeight;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF111827),
        appBar: AppBar(
          title: Text('progress.title').tr(),
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

                              VolumeChartCard(selectedDays: _selectedDays),
                              const SizedBox(height: 12),
                              // Кнопка записать вес
                              // Умная кнопка веса
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1F2937),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.monitor_weight,
                                      color: Color(0xFFF97316),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    // Если сегодня записан — показываем вес
                                    if (_todayWeight != null) ...[
                                      Text(
                                        '${_todayWeight!.weight} ${'workout.kg'.tr()}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'progress.today'.tr(),
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        'progress.no_weight_today'.tr(),
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    // Кнопка записать/изменить
                                    GestureDetector(
                                      onTap: _showAddWeightDialog,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF97316),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _todayWeight != null
                                              ? 'progress.edit_weight'.tr()
                                              : 'progress.add_weight_short'
                                                  .tr(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              BodyWeightChartCard(selectedDays: _selectedDays),
                              const SizedBox(height: 12),
                              ExerciseProgressCard(selectedDays: _selectedDays),
                            ],
                          )))
                ],
              ));
  }

// Показать диалог для записи веса тела
  Future<void> _showAddWeightDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF97316), width: 2),
        ),
        titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text(
          'progress.add_weight_title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                labelText: 'progress.weight_kg'.tr(),
                labelStyle: const TextStyle(
                  color: Color(0xFFF97316),
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.monitor_weight,
                  color: Color(0xFFF97316),
                  size: 18,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final weight = double.tryParse(controller.text.trim());
              if (weight == null || weight <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('progress.weight_invalid'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, weight);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: Text('progress.save_weight'.tr()),
          ),
        ],
      ),
    );

    // Если пользователь ввёл вес — сохраняем
    if (result != null) {
      await _bodyWeightService.saveEntry(result);
      // Перезагружаем данные чтобы график обновился
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('progress.weight_saved'.tr()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
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
