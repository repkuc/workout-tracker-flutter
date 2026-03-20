import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/workout_service.dart';

class VolumeChartCard extends StatefulWidget {
  // Принимаем выбранный период снаружи (из ProgressPage)
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

  // Данные для графика: список пар (дата, объём)
  List<MapEntry<String, double>> _volumeData = [];
  double _totalVolume = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Когда родитель меняет фильтр — перезагружаем данные
  @override
  void didUpdateWidget(VolumeChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDays != widget.selectedDays) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Получаем Map от сервиса и превращаем в отсортированный список
    final volumeMap = await _workoutService.getVolumeByDate(
      days: widget.selectedDays,
    );

    // Сортируем по дате (старые слева, новые справа)
    final sorted = volumeMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Считаем суммарный объём за период
    final total = sorted.fold(0.0, (sum, e) => sum + e.value);

    setState(() {
      _volumeData = sorted;
      _totalVolume = total;
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

          const SizedBox(height: 16),

          // График или заглушки
          SizedBox(
            height: 130,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFF97316),
                    ),
                  )
                : _volumeData.isEmpty
                    ? Center(
                        child: Text(
                          'progress.no_data'.tr(),
                          style: const TextStyle(color: Color(0xFF6B7280)),
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
        // Убираем рамку вокруг графика
        borderData: FlBorderData(show: false),

        // Настройки сетки
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false, // вертикальные линии не нужны
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFF374151),
            strokeWidth: 1,
          ),
        ),

        // Подписи осей
        titlesData: FlTitlesData(
          // Убираем подписи сверху и справа
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          // Подписи снизу — даты
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _volumeData.length) {
                  return const SizedBox();
                }
                // Показываем только каждую N-ю метку чтобы не толпились
                final step = (_volumeData.length / 4).ceil();
                if (index % step != 0) return const SizedBox();

                // Берём только день и месяц из даты "2024-03-15" → "03.15"
                final date = _volumeData[index].key;
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
          // Подписи слева — объём
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

        // Сами столбики
        barGroups: _volumeData.asMap().entries.map((entry) {
          final index = entry.key;
          final volume = entry.value.value;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: volume,
                color: const Color(0xFFF97316),
                width: _volumeData.length > 20 ? 4 : 10,
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
}