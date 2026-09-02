// Подключаем базовые виджеты Flutter.
import 'package:flutter/material.dart';

// Подключаем easy_localization для переводов.
import 'package:easy_localization/easy_localization.dart';

// Подключаем модель и сервис замеров.
import '../models/body_measurement_entry.dart';
import '../services/body_measurement_service.dart';

// Подключаем fl_chart для графика.
import 'package:fl_chart/fl_chart.dart';

class BodyMeasurementsPage extends StatefulWidget {
  const BodyMeasurementsPage({super.key});

  @override
  State<BodyMeasurementsPage> createState() => _BodyMeasurementsPageState();
}

class _BodyMeasurementsPageState extends State<BodyMeasurementsPage> {
  final _service = BodyMeasurementService();

  List<BodyMeasurementEntry> _entries = [];
  bool _isLoading = true;

  // Список всех видов замеров с их ключами, названиями (через перевод) и цветами.
  // Это единый источник правды который используем и в форме добавления,
  // и в чипсах графика, и в списке истории — чтобы не дублировать данные
  // в нескольких местах.
  static const List<Map<String, dynamic>> _measurementTypes = [
    {
      'key': 'neck',
      'labelKey': 'measurements.neck',
      'color': Color(0xFFF97316)
    },
    {
      'key': 'shoulders',
      'labelKey': 'measurements.shoulders',
      'color': Color(0xFF818CF8)
    },
    {
      'key': 'chest',
      'labelKey': 'measurements.chest',
      'color': Color(0xFF34D399)
    },
    {
      'key': 'waist',
      'labelKey': 'measurements.waist',
      'color': Color(0xFFF472B6)
    },
    {
      'key': 'hips',
      'labelKey': 'measurements.hips',
      'color': Color(0xFFFBBF24)
    },
    {
      'key': 'bicep',
      'labelKey': 'measurements.bicep',
      'color': Color(0xFF60A5FA)
    },
    {
      'key': 'forearm',
      'labelKey': 'measurements.forearm',
      'color': Color(0xFFA78BFA)
    },
    {
      'key': 'thigh',
      'labelKey': 'measurements.thigh',
      'color': Color(0xFF34D399)
    },
    {
      'key': 'calf',
      'labelKey': 'measurements.calf',
      'color': Color(0xFFE879F9)
    },
  ];

  // Ключи замеров которые сейчас включены на графике — по умолчанию
  // включаем первые два, чтобы график не был пустым при первом открытии,
  // но и не был перегружен девятью линиями сразу.
  Set<String> _visibleKeys = {'waist', 'chest'};

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await _service.loadAllEntries();
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFF97316)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildAddButton(),
          const SizedBox(height: 12),
          if (_entries.isNotEmpty) _buildChartCard(),
          const SizedBox(height: 16),
          _buildHistorySection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Кнопка добавления нового замера.
  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _showAddMeasurementDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF97316).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: Color(0xFFF97316), size: 18),
            const SizedBox(width: 6),
            Text(
              'measurements.add_measurement'.tr(),
              style: const TextStyle(
                  color: Color(0xFFF97316),
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // График замеров тела — линии для каждого включённого вида замера,
  // плюс чипсы под графиком чтобы включать/выключать какие линии видны.
  Widget _buildChartCard() {
    // Берём записи в хронологическом порядке (старые слева, новые справа) —
    // _entries у нас отсортирован от новых к старым, разворачиваем.
    final chronological = _entries.reversed.toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            child: chronological.length < 2
                // Графику нужно минимум 2 точки чтобы нарисовать линию —
                // если записей меньше, просто показываем подсказку.
                ? Center(
                    child: Text(
                      'measurements.need_more_data'.tr(),
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 12),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                            color: const Color(0xFF374151), strokeWidth: 0.8),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt()}',
                              style: const TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= chronological.length)
                                return const SizedBox();
                              // Показываем не каждую точку а прорежённо, чтобы подписи не слипались.
                              final step = (chronological.length / 4)
                                  .ceil()
                                  .clamp(1, chronological.length);
                              if (index % step != 0) return const SizedBox();
                              final date =
                                  DateTime.tryParse(chronological[index].date);
                              if (date == null) return const SizedBox();
                              return Text(
                                '${date.day}.${date.month}',
                                style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 9),
                              );
                            },
                          ),
                        ),
                      ),
                      // Строим одну линию на каждый включённый вид замера.
                      lineBarsData: _visibleKeys.map((key) {
                        final type = _measurementTypes
                            .firstWhere((t) => t['key'] == key);
                        final color = type['color'] as Color;

                        // Собираем точки только там где значение реально есть —
                        // fl_chart соединит их линией пропуская дни без этого замера.
                        final spots = <FlSpot>[];
                        for (int i = 0; i < chronological.length; i++) {
                          final value = chronological[i].getByKey(key);
                          if (value != null) {
                            spots.add(FlSpot(i.toDouble(), value));
                          }
                        }

                        return LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: color,
                          barWidth: 2,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(show: false),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 10),

          // Чипсы для включения/выключения замеров на графике.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _measurementTypes.map((type) {
              final key = type['key'] as String;
              final color = type['color'] as Color;
              final isVisible = _visibleKeys.contains(key);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isVisible) {
                      _visibleKeys.remove(key);
                    } else {
                      _visibleKeys.add(key);
                    }
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isVisible
                        ? color.withOpacity(0.15)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isVisible ? color : const Color(0xFF374151)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: isVisible ? color : const Color(0xFF64748B),
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (type['labelKey'] as String).tr(),
                        style: TextStyle(
                          color: isVisible ? color : const Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight:
                              isVisible ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Секция с историей записей.
  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'measurements.history'.tr(),
          style: const TextStyle(
              color: Color(0xFF64748B), fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        if (_entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'measurements.no_entries'.tr(),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
          )
        else
          ..._entries.map((e) => _buildHistoryItem(e)).toList(),
      ],
    );
  }

  // Одна запись в истории — дата + все заполненные замеры в этот день.
  Widget _buildHistoryItem(BodyMeasurementEntry entry) {
    // Собираем список пар (метка, значение) только для тех полей которые заполнены.
    final filledValues = _measurementTypes
        .where((type) => entry.getByKey(type['key'] as String) != null)
        .map((type) =>
            '${(type['labelKey'] as String).tr()} ${entry.getByKey(type['key'] as String)}см')
        .join('  ·  ');

    final dateTime = DateTime.tryParse(entry.date);
    final formattedDate = dateTime != null
        ? '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}'
        : entry.date;

    return GestureDetector(
      onTap: () => _showEditMeasurementDialog(entry), 
      onLongPress: () => _showDeleteEntryDialog(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              child: Text(formattedDate,
                  style:
                      const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            ),
            Expanded(
              child: Text(
                filledValues,
                style: const TextStyle(color: Colors.white, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Диалог подтверждения удаления записи (по долгому нажатию).
  Future<void> _showDeleteEntryDialog(BodyMeasurementEntry entry) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.red, width: 1)),
        title: Text('workout.delete_workout_confirm'.tr(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('workout.cancel'.tr(),
                style: const TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );

    if (result == true) {
      await _service.deleteEntry(entry.date);
      await _loadEntries();
    }
  }

    // Диалог добавления сегодняшней записи ИЛИ редактирования уже существующей.
  // Если entryToEdit передан — редактируем именно её (любую дату из истории).
  // Если не передан — работаем с сегодняшней датой (как раньше).
  Future<void> _showAddMeasurementDialog({BodyMeasurementEntry? entryToEdit}) async {
    // Если редактируем — берём переданную запись.
    // Если добавляем — подгружаем сегодняшнюю (на случай что уже частично заполнена).
    final targetEntry = entryToEdit ?? await _service.getTodayEntry();

    final Map<String, TextEditingController> controllers = {
      for (final type in _measurementTypes)
        type['key'] as String: TextEditingController(
          text: targetEntry?.getByKey(type['key'] as String)?.toString() ?? '',
        ),
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF97316), width: 1),
        ),
        title: Text(
          // Заголовок отличается — "Добавить замер" или "Редактировать замер".
          entryToEdit != null ? 'measurements.edit_measurement'.tr() : 'measurements.add_measurement'.tr(),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'measurements.fill_hint'.tr(),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
                const SizedBox(height: 12),
                ..._measurementTypes.map((type) {
                  final key = type['key'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[key],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        labelText: (type['labelKey'] as String).tr(),
                        labelStyle: TextStyle(color: type['color'] as Color, fontSize: 12),
                        suffixText: 'см',
                        suffixStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('workout.cancel'.tr(), style: const TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('workout.save'.tr()),
          ),
        ],
      ),
    );

    if (result == true) {
      final entry = BodyMeasurementEntry(
        // Дата остаётся той же что была у редактируемой записи,
        // либо сегодняшней если это новая запись.
        date: targetEntry?.date ?? _getTodayDate(),
        neck: double.tryParse(controllers['neck']!.text.trim()),
        shoulders: double.tryParse(controllers['shoulders']!.text.trim()),
        chest: double.tryParse(controllers['chest']!.text.trim()),
        waist: double.tryParse(controllers['waist']!.text.trim()),
        hips: double.tryParse(controllers['hips']!.text.trim()),
        bicep: double.tryParse(controllers['bicep']!.text.trim()),
        forearm: double.tryParse(controllers['forearm']!.text.trim()),
        thigh: double.tryParse(controllers['thigh']!.text.trim()),
        calf: double.tryParse(controllers['calf']!.text.trim()),
      );

      await _service.saveEntry(entry);
      await _loadEntries();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('measurements.saved'.tr()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  // Обёртка для читаемости — вызывается при нажатии на запись в истории.
  Future<void> _showEditMeasurementDialog(BodyMeasurementEntry entry) async {
    await _showAddMeasurementDialog(entryToEdit: entry);
  }

  // Получить сегодняшнюю дату в формате YYYY-MM-DD (дублируем логику
  // сервиса здесь, так как она приватная там).
  String _getTodayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
