import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/workout_service.dart';

class ExerciseProgressCard extends StatefulWidget {
  final int? selectedDays;

  const ExerciseProgressCard({
    super.key,
    required this.selectedDays,
  });

  @override
  State<ExerciseProgressCard> createState() => _ExerciseProgressCardState();
}

class _ExerciseProgressCardState extends State<ExerciseProgressCard> {
  final _workoutService = WorkoutService();

  // Все данные прогресса: { "Жим лёжа": [(дата, вес), ...], ... }
  Map<String, List<MapEntry<String, double>>> _allData = {};
  // Топ-5 упражнений — включены по умолчанию
  List<String> _topExercises = [];
  // Какие упражнения сейчас включены (видны на графике)
  Set<String> _activeExercises = {};
  bool _isLoading = true;
  bool _chipsExpanded = false; // Состояние для показа всех упражнений или только топ-5

  // Цвета для линий упражнений
  final List<Color> _colors = [
    const Color(0xFFF97316), // оранжевый
    const Color(0xFF34D399), // зелёный
    const Color(0xFF818CF8), // фиолетовый
    const Color(0xFF38BDF8), // голубой
    const Color(0xFFFB7185), // розовый
    const Color(0xFFFBBF24), // жёлтый
    const Color(0xFFA78BFA), // лавандовый
    const Color(0xFF6EE7B7), // мятный
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(ExerciseProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDays != widget.selectedDays) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Загружаем прогресс упражнений и топ-5
    final data = await _workoutService.getExerciseProgressByDate(
      days: widget.selectedDays,
    );
    final top = await _workoutService.getTopExercises(limit: 5);

    setState(() {
      _allData = data;
      _topExercises = top;
      // По умолчанию включаем только топ-5
      _activeExercises = top.toSet();
      _isLoading = false;
    });
  }

  // Получить цвет для упражнения по его индексу
  Color _colorFor(String name) {
    final allNames = _allData.keys.toList();
    final index = allNames.indexOf(name) % _colors.length;
    return _colors[index];
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
          // Заголовок
          Text(
            'progress.exercises_title'.tr(),
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Чипы упражнений
          _isLoading
              ? const SizedBox()
              : _buildChips(),

          const SizedBox(height: 12),

          // График
          SizedBox(
            height: 180,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFF97316),
                    ),
                  )
                : _activeExercises.isEmpty || _allData.isEmpty
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

  // Чипы — кнопки включения/выключения упражнений
 Widget _buildChips() {
  if (_allData.isEmpty) {
    return Center(
      child: Text(
        'progress.no_data'.tr(),
        style: const TextStyle(color: Color(0xFF6B7280)),
      ),
    );
  }

  // Показываем топ-5 или все в зависимости от состояния
  final allNames = _allData.keys.toList();
  final visibleNames = _chipsExpanded ? allNames : allNames.take(5).toList();
  final hasMore = allNames.length > 5;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: visibleNames.map((name) {
          final isActive = _activeExercises.contains(name);
          final color = _colorFor(name);

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isActive) {
                  _activeExercises.remove(name);
                } else {
                  _activeExercises.add(name);
                }
              });
            },
            child: Opacity(
              opacity: isActive ? 1.0 : 0.35,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.45,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(color: color, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),

      // Кнопка свернуть/развернуть
      if (hasMore) ...[
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _chipsExpanded = !_chipsExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _chipsExpanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF9CA3AF),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _chipsExpanded
                      ? 'progress.show_less'.tr()
                      : 'progress.show_more'.tr(
                          namedArgs: {'count': '${allNames.length - 5}'},
                        ),
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

  Widget _buildChart() {
    // Собираем все уникальные даты из активных упражнений
    final allDates = <String>{};
    for (final name in _activeExercises) {
      if (_allData.containsKey(name)) {
        for (final entry in _allData[name]!) {
          allDates.add(entry.key);
        }
      }
    }

    // Сортируем даты
    final sortedDates = allDates.toList()..sort();
    if (sortedDates.isEmpty) return const SizedBox();

    // Строим линии для каждого активного упражнения
    final lines = <LineChartBarData>[];
    for (final name in _activeExercises) {
      if (!_allData.containsKey(name)) continue;
      final data = _allData[name]!;
      if (data.isEmpty) continue;

      // Точки графика — X это индекс даты, Y это вес
      final spots = data.map((entry) {
        final x = sortedDates.indexOf(entry.key).toDouble();
        final y = entry.value;
        return FlSpot(x, y);
      }).toList();

      lines.add(LineChartBarData(
        spots: spots,
        color: _colorFor(name),
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) =>
              FlDotCirclePainter(
                radius: 3,
                color: _colorFor(name),
                strokeWidth: 0,
              ),
        ),
        isCurved: true,
        curveSmoothness: 0.3,
        belowBarData: BarAreaData(show: false),
      ));
    }

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
                if (index < 0 || index >= sortedDates.length) {
                  return const SizedBox();
                }
                // Показываем каждую N-ю метку
                final step = (sortedDates.length / 4).ceil();
                if (index % step != 0) return const SizedBox();

                final date = sortedDates[index];
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
                  '${value.toInt()}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: lines,
      ),
    );
  }
}