import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/body_weight_service.dart';
import '../models/body_weight_entry.dart';
import '../widgets/volume_chart_card.dart';
import '../widgets/exercise_progress_card.dart';
import '../widgets/body_weight_chart_card.dart';
import '../theme/app_colors.dart';
import '../widgets/app_dialog.dart';

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
    return Container(
      color: AppColors.background,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : Column(
              children: [
                _buildFilters(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        VolumeChartCard(selectedDays: _selectedDays),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.monitor_weight,
                                  color: AppColors.bodyWeight, size: 20),
                              const SizedBox(width: 10),
                              if (_todayWeight != null) ...[
                                Text(
                                  '${_todayWeight!.weight} ${'workout.kg'.tr()}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 6),
                                Text('progress.today'.tr(),
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12)),
                              ] else ...[
                                Text('progress.no_weight_today'.tr(),
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 13)),
                              ],
                              const Spacer(),
                              GestureDetector(
                                onTap: _showAddWeightDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.bodyWeight
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.bodyWeight
                                            .withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    _todayWeight != null
                                        ? 'progress.edit_weight'.tr()
                                        : 'progress.add_weight_short'.tr(),
                                    style: const TextStyle(
                                        color: AppColors.bodyWeight,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
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
                    ),
                  ),
                ),
              ],
            ),
    );
  }

// Показать диалог для записи веса тела
  Future<void> _showAddWeightDialog() async {
    final controller = TextEditingController();

    // Ошибку неверного веса показываем прямо под полем
    String? weightError;

    final result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          title: 'progress.add_weight_title'.tr(),
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
                // Начали печатать — убираем ошибку
                onChanged: (_) {
                  if (weightError != null) {
                    setDialogState(() => weightError = null);
                  }
                },
                decoration: appDialogInputDecoration(
                  labelText: 'progress.weight_kg'.tr(),
                  icon: Icons.monitor_weight,
                  errorText: weightError,
                ),
              ),
            ],
          ),
          actions: [
            AppDialogCancelButton(
              label: 'workout.cancel'.tr(),
              onPressed: () => Navigator.pop(context, null),
            ),
            AppDialogConfirmButton(
              label: 'progress.save_weight'.tr(),
              onPressed: () {
                final weight = double.tryParse(controller.text.trim());
                if (weight == null || weight <= 0) {
                  setDialogState(
                      () => weightError = 'progress.weight_invalid'.tr());
                  return;
                }
                Navigator.pop(context, weight);
              },
            ),
          ],
        ),
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
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Widget _buildFilters() {
    final filters = [
      ('progress.filter_7d'.tr(), 7),
      ('progress.filter_30d'.tr(), 30),
      ('progress.filter_year'.tr(), 365),
      ('progress.filter_all'.tr(), null),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: filters.map((filter) {
          final label = filter.$1;
          final days = filter.$2;
          final isActive = _selectedDays == days;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedDays = days);
                  _loadData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.accent
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color:
                            isActive ? Colors.white : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
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
