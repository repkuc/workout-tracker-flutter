import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/body_weight_service.dart';
import '../models/body_weight_entry.dart';

class BodyWeightChartCard extends StatefulWidget {
  final int? selectedDays;

  const BodyWeightChartCard({
    super.key,
    required this.selectedDays,
  });

  @override
  State<BodyWeightChartCard> createState() => _BodyWeightChartCardState();
}

class _BodyWeightChartCardState extends State<BodyWeightChartCard> {
  final _service = BodyWeightService();
  List<BodyWeightEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(BodyWeightChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDays != widget.selectedDays) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final entries = widget.selectedDays == null
        ? await _service.getAllEntries()
        : await _service.getEntriesForDays(widget.selectedDays!);

    setState(() {
      _entries = entries;
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
          // Заголовок + текущий вес
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'progress.weight_title'.tr(),
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
                        : _entries.isEmpty
                            ? '—'
                            : '${_entries.last.weight} ${'workout.kg'.tr()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Дельта — разница между первой и последней записью
              if (!_isLoading && _entries.length >= 2)
                _buildDelta(),
            ],
          ),

          const SizedBox(height: 16),

          // График
          SizedBox(
            height: 120,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFF97316),
                    ),
                  )
                : _entries.isEmpty
                    ? Center(
                        child: Text(
                          'progress.no_data'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      )
                    : _entries.length == 1
                        ? Center(
                            child: Text(
                              '${_entries.first.weight} ${'workout.kg'.tr()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : _buildChart(),
          ),
        ],
      ),
    );
  }

  // Бейдж с дельтой (разница между первым и последним весом)
  Widget _buildDelta() {
    final first = _entries.first.weight;
    final last = _entries.last.weight;
    final delta = last - first;
    final isDown = delta < 0; // похудел = хорошо (зелёный)

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDown
            ? const Color(0xFF064E3B) // тёмно-зелёный
            : const Color(0xFF7C2D12), // тёмно-красный
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${isDown ? '' : '+'}${delta.toStringAsFixed(1)} ${'workout.kg'.tr()}',
        style: TextStyle(
          color: isDown ? const Color(0xFF34D399) : const Color(0xFFFB7185),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildChart() {
    // Превращаем записи в точки графика
    final spots = _entries.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.weight);
    }).toList();

    // Минимум и максимум для оси Y — добавляем отступ
    final weights = _entries.map((e) => e.weight).toList();
    final minY = weights.reduce((a, b) => a < b ? a : b) - 1;
    final maxY = weights.reduce((a, b) => a > b ? a : b) + 1;

    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFF374151),
            strokeWidth: 1,
          ),
        ),
        minY: minY,
        maxY: maxY,
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
                if (index < 0 || index >= _entries.length) {
                  return const SizedBox();
                }
                final step = (_entries.length / 4).ceil();
                if (index % step != 0) return const SizedBox();

                final date = _entries[index].date;
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
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: const Color(0xFFE879F9), // фиолетовый — как чип веса
            barWidth: 2,
            isCurved: true,
            curveSmoothness: 0.3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                    radius: 3,
                    color: const Color(0xFFE879F9),
                    strokeWidth: 0,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFE879F9).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}