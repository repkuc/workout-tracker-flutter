import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/body_weight_service.dart';
import '../models/body_weight_entry.dart';
import '../theme/app_colors.dart';
import 'chart_helpers.dart';

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
        color: AppColors.chartCard,
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
                      color: AppColors.chartText,
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
              if (!_isLoading && _entries.length >= 2) _buildDelta(),
            ],
          ),

          const SizedBox(height: 16),

          // График
          SizedBox(
            height: 120,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
                  )
                : _entries.isEmpty
                    ? Center(
                        child: Text(
                          'progress.no_data'.tr(),
                          style: const TextStyle(
                            color: AppColors.chartTextMuted,
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
  Widget _buildDelta() => ChartChangeBadge(
        delta: _entries.last.weight - _entries.first.weight,
        unit: 'workout.kg'.tr(),
      );

  // График по общим правилам (chart_helpers.dart): ось X по времени,
  // круглые деления по весу, точка только на последней записи, если записей много.
  Widget _buildChart() {
    final kg = 'workout.kg'.tr();
    final weights = _entries.map((e) => e.weight).toList();
    final scale = ChartScale.nice(weights.reduce((a, b) => a < b ? a : b),
        weights.reduce((a, b) => a > b ? a : b));
    final days = _entries.map((e) => chartDayOf(chartParseDate(e.date))).toList();

    return LayoutBuilder(builder: (context, constraints) {
      final axis = ChartTimeAxis.build(
        context,
        firstDay: days.first,
        lastDay: days.last,
        plotWidth: constraints.maxWidth - scale.leftWidth(context, kg),
      );
      final spots = [
        for (var i = 0; i < _entries.length; i++)
          FlSpot(axis.x(days[i]), scale.toChart(weights[i])),
      ];

      return LineChart(
        LineChartData(
          borderData: FlBorderData(show: false),
          minX: axis.minX,
          maxX: axis.maxX,
          minY: 0,
          maxY: scale.maxY,
          gridData: scale.grid(),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: axis.bottomTitles(),
            leftTitles: scale.leftTitles(context, kg),
          ),
          lineTouchData: chartLineTouch(
            items: (touched) => touched.map((spot) {
              final entry = _entries[spot.spotIndex];
              return LineTooltipItem(
                '${chartTooltipDate(chartParseDate(entry.date))}\n',
                kChartTooltipTitleStyle,
                children: [
                  TextSpan(
                    text: '${chartNumber(entry.weight)} $kg',
                    style: chartTooltipValueStyle(AppColors.bodyWeight),
                  ),
                ],
              );
            }).toList(),
          ),
          lineBarsData: [
            chartLine(spots: spots, color: AppColors.bodyWeight, area: true),
          ],
        ),
      );
    });
  }
}
