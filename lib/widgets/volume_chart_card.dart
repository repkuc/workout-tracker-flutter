import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/workout_service.dart';

class VolumeChartCard extends StatefulWidget {
  final int? selectedDays;

  const VolumeChartCard({
    super.key,
    required this.selectedDays,
  });

  @override
  State<VolumeChartCard> createState() => _VolumeChartCardState();
}

class _VolumeChartCardState extends State<VolumeChartCard> {
  final _workoutService = WorkoutService();

  // Список записей: [{date, volume, name}, ...]
  List<Map<String, dynamic>> _data = [];
  double _totalVolume = 0;
  bool _isLoading = true;

  // Цвета для разных тренировок
  final List<Color> _colors = [
    const Color(0xFFF97316), // оранжевый
    const Color(0xFF34D399), // зелёный
    const Color(0xFF60A5FA), // голубой
    const Color(0xFFF472B6), // розовый
    const Color(0xFFA78BFA), // фиолетовый
    const Color(0xFFFBBF24), // жёлтый
  ];

  // Уникальные названия тренировок → цвет
  Map<String, Color> _nameColors = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(VolumeChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDays != widget.selectedDays) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final data = await _workoutService.getVolumeByDateWithName(
      days: widget.selectedDays,
    );

    // Назначаем цвет каждому уникальному названию тренировки
    final Map<String, Color> nameColors = {};
    int colorIndex = 0;
    for (final item in data) {
      final name = item['name'] as String;
      if (!nameColors.containsKey(name)) {
        final colorStr = item['color'] as String?;
        if (colorStr != null && colorStr.isNotEmpty) {
          nameColors[name] = Color(int.parse('0xFF${colorStr.substring(1)}'));
        } else {
          nameColors[name] = _colors[colorIndex % _colors.length];
          colorIndex++;
        }
      }
    }

    final total = data.fold<double>(
      0,
      (sum, item) => sum + (item['volume'] as double),
    );

    setState(() {
      _data = data;
      _totalVolume = total;
      _nameColors = nameColors;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок + суммарный объём
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'progress.volume_title'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLoading
                        ? '...'
                        : '${(_totalVolume / 1000).toStringAsFixed(1)}т',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Легенда — названия тренировок с цветами
          if (!_isLoading && _nameColors.isNotEmpty)
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: _nameColors.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: entry.value,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.35,
                      ),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),

          const SizedBox(height: 12),

          // График
          SizedBox(
            height: 150,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFF97316),
                    ),
                  )
                : _data.isEmpty
                    ? Center(
                        child: Text(
                          'progress.no_data'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      )
                    : _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return BarChart(
      BarChartData(
        minY: _calcMinY(), // ← ДОБАВЬ
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          // Больше горизонтальных линий — лучше видна прогрессия
          horizontalInterval: _calcInterval(),
          getDrawingHorizontalLine: (value) {
            // Каждые 5т — яркая линия-рубеж
            final is5t = value % 5000 == 0;
            return FlLine(
              color: is5t
                  ? const Color(0xFF6B7280) // ярче
                  : const Color(0xFF374151), // обычная тёмная
              strokeWidth: is5t ? 1.5 : 0.8,
            );
          },
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _data.length) {
                  return const SizedBox();
                }
                final step = (_data.length / 4).ceil();
                if (index % step != 0) return const SizedBox();

                final date = _data[index]['date'] as String;
                final parts = date.split('-');
                return Text(
                  '${parts[2]}.${parts[1]}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${(value / 1000).toStringAsFixed(1)}т',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: _data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final name = item['name'] as String;
          final volume = item['volume'] as double;
          final color = _nameColors[name] ?? const Color(0xFFF97316);

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: volume,
                color: color,
                width: _data.length > 20 ? 4 : 8,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // Считаем интервал для горизонтальных линий
  // Чем меньше интервал — тем больше линий — тем лучше видна прогрессия
  double _calcInterval() {
    // if (_data.isEmpty) return 1000;
    // final maxVolume =
    //     _data.map((e) => e['volume'] as double).reduce((a, b) => a > b ? a : b);
    // // Делим на 10 вместо 6 — больше горизонтальных линий
    // return (maxVolume / 10).roundToDouble();
    return 1000; // деление каждые 2т — много линий
  }

  double _calcMinY() {
    // if (_data.isEmpty) return 0;
    // final minVolume =
    //     _data.map((e) => e['volume'] as double).reduce((a, b) => a < b ? a : b);
    // // Начинаем чуть ниже минимума чтобы был отступ снизу
    // return (minVolume * 0.7).roundToDouble();
    return 0; // всегда от 0 — так лучше видно прогрессию, особенно если объёмы растут от 0 до нескольких тысяч
  }
}
