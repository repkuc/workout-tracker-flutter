import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/workout_service.dart';
import '../theme/app_colors.dart';
import 'chart_helpers.dart';
import 'exercise_display.dart';
import 'tab_visibility.dart';

class ExerciseProgressCard extends StatefulWidget {
  final int? selectedDays;

  const ExerciseProgressCard({
    super.key,
    required this.selectedDays,
  });

  @override
  State<ExerciseProgressCard> createState() => _ExerciseProgressCardState();
}

class _ExerciseProgressCardState extends State<ExerciseProgressCard>
    with ReloadWhenVisible {
  final _workoutService = WorkoutService();

  // Все данные прогресса по ключу упражнения (WorkoutService.exerciseKey):
  // { "chest_1": [(дата, вес), ...], ... }. Подписи — exerciseKeyLabel,
  // цвет — по порядку ключей, поэтому при смене языка он не меняется.
  Map<String, List<MapEntry<String, double>>> _allData = {};
  // Ключ → самое новое сохранённое название (подпись без шаблона в каталоге)
  Map<String, String> _latestNames = {};
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
    // Данные тренировок изменились (например, в «Моих упражнениях») — перечитываем
    _workoutService.dataChanged.addListener(onWorkoutDataChanged);
  }

  @override
  void dispose() {
    _workoutService.dataChanged.removeListener(onWorkoutDataChanged);
    super.dispose();
  }

  // Изменение данных: видимая вкладка перечитывает сразу, скрытая — при показе
  @override
  void reloadVisibleData() => _loadData(showSpinner: false);

  @override
  void didUpdateWidget(ExerciseProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDays != widget.selectedDays) {
      _loadData();
    }
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);

    // Загружаем прогресс упражнений и топ-5
    final data = await _workoutService.getExerciseProgressByDate(
      days: widget.selectedDays,
    );
    final top = await _workoutService.getTopExercises(limit: 5);
    final latestNames = await _workoutService.getLatestExerciseNames();
    if (!mounted) return;

    setState(() {
      _allData = data;
      _latestNames = latestNames;
      _topExercises = top;
      // По умолчанию включаем только топ-5
      _activeExercises = top.toSet();
      _isLoading = false;
    });
  }

  // Получить цвет для упражнения по индексу его ключа
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
        color: AppColors.chartCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Text(
            'progress.exercises_title'.tr(),
            style: const TextStyle(
              color: AppColors.chartText,
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
                      color: AppColors.accent,
                    ),
                  )
                : _activeExercises.isEmpty || _allData.isEmpty
                    ? Center(
                        child: Text(
                          'progress.no_data'.tr(),
                          style: const TextStyle(color: AppColors.chartTextMuted),
                        ),
                      )
                    : _buildChart(),
          ),

          // Итог по каждому видимому упражнению: лучший вес и изменение
          if (!_isLoading) ..._buildSummaryRows(),
        ],
      ),
    );
  }

  // Видимые упражнения с данными — в порядке ключей (как цвета и чипы)
  List<String> get _visibleKeys => _allData.keys
      .where((k) => _activeExercises.contains(k) && _allData[k]!.isNotEmpty)
      .toList();

  // «Жим штанги лёжа — 97.5 кг · +12.5 кг» цветом линии; изменение
  // (первое → последнее значение периода) — только если точек больше одной
  List<Widget> _buildSummaryRows() {
    final kg = 'workout.kg'.tr();
    final keys = _visibleKeys;
    if (keys.isEmpty) return [];
    return [
      const SizedBox(height: 10),
      for (final key in keys)
        Builder(builder: (context) {
          final points = _allData[key]!;
          final best = points.map((e) => e.value).reduce((a, b) => a > b ? a : b);
          final change = points.last.value - points.first.value;
          final color = _colorFor(key);
          final values = points.length > 1
              ? '${chartNumber(best)} $kg · ${chartSignedNumber(change)} $kg'
              : '${chartNumber(best)} $kg';
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    exerciseKeyLabel(context, key, _latestNames),
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  values,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
    ];
  }

  // Чипы — кнопки включения/выключения упражнений
 Widget _buildChips() {
  if (_allData.isEmpty) {
    return Center(
      child: Text(
        'progress.no_data'.tr(),
        style: const TextStyle(color: AppColors.chartTextMuted),
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
                      // Длинное название — в 2 строки, а не обрезка «…» сразу
                      child: Text(
                        exerciseKeyLabel(context, name, _latestNames),
                        style: TextStyle(color: color, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
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
              color: AppColors.chartPill,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _chipsExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.chartText,
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
                    color: AppColors.chartText,
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


  // График по общим правилам (chart_helpers.dart): ось X по времени (даты
  // видимых упражнений), круглые деления веса, прямые линии, точки — по правилу.
  // Невидимая линия-«сетка дат» ловит касание: подсказка показывает ВСЕ
  // видимые упражнения, у которых есть значение в эту дату, полными названиями.
  Widget _buildChart() {
    final keys = _visibleKeys;
    if (keys.isEmpty) return const SizedBox();
    final kg = 'workout.kg'.tr();

    // Все даты видимых упражнений и значения: ключ → {день → вес}
    final byDay = <String, Map<int, double>>{
      for (final key in keys)
        key: {
          for (final e in _allData[key]!)
            chartDayOf(chartParseDate(e.key)): e.value,
        },
    };
    final days = byDay.values.expand((m) => m.keys).toSet().toList()..sort();
    final values = byDay.values.expand((m) => m.values);
    final scale = ChartScale.nice(values.reduce((a, b) => a < b ? a : b),
        values.reduce((a, b) => a > b ? a : b));

    return LayoutBuilder(builder: (context, constraints) {
      final axis = ChartTimeAxis.build(
        context,
        firstDay: days.first,
        lastDay: days.last,
        plotWidth: constraints.maxWidth - scale.leftWidth(context, kg),
      );

      final lines = [
        for (final key in keys)
          chartLine(
            spots: [
              for (final entry in byDay[key]!.entries)
                FlSpot(axis.x(entry.key), scale.toChart(entry.value)),
            ],
            color: _colorFor(key),
          ),
        chartDateGuideLine([for (final d in days) axis.x(d)], 0),
      ];
      final guideIndex = lines.length - 1;

      List<LineTooltipItem?> tooltip(List<LineBarSpot> touched) {
        final guide = touched.where((s) => s.barIndex == guideIndex);
        if (guide.isEmpty) return List.filled(touched.length, null);
        final day = axis.dayAtX(guide.first.x);
        final rows = <TextSpan>[
          for (final key in keys)
            if (byDay[key]![day] != null)
              TextSpan(
                text: '\n${exerciseKeyLabel(context, key, _latestNames)}: '
                    '${chartNumber(byDay[key]![day]!)} $kg',
                style: chartTooltipValueStyle(_colorFor(key)),
              ),
        ];
        return [
          for (final s in touched)
            s.barIndex == guideIndex && identical(s, guide.first)
                ? LineTooltipItem(
                    chartTooltipDate(chartDateOfDay(day)),
                    kChartTooltipTitleStyle,
                    textAlign: TextAlign.left,
                    children: rows,
                  )
                : null,
        ];
      }

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
          lineTouchData: chartLineTouch(items: tooltip, hasDateGuide: true),
          lineBarsData: lines,
        ),
      );
    });
  }
}
