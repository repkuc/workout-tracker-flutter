import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'progress_page.dart';
import '../services/workout_service.dart';
import '../models/workout_models.dart';
import 'body_measurements_page.dart'; // Импортируем страницу замеров тела
import '../theme/app_colors.dart';
import '../widgets/tab_header.dart';
import '../widgets/exercise_display.dart';
import '../widgets/exercise_info_button.dart';
import '../widgets/segmented_tab_switch.dart';
import '../widgets/tab_visibility.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Шапка
            TabHeader(
              icon: Icons.bar_chart,
              title: 'statistics.title'.tr(),
              bottomPadding: 8,
            ),

            // Табы
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: const [
                    Tab(icon: Icon(Icons.dashboard, size: 20)),
                    Tab(icon: Icon(Icons.show_chart, size: 20)),
                    Tab(icon: Icon(Icons.straighten, size: 20)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Контент табов
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  // Таб 1 — Обзор (бывшая статистика)
                  _OverviewTab(),
                  // Таб 2 — Графики (бывший прогресс)
                  ProgressPage(),
                  // Таб 3 — Замеры тела
                  BodyMeasurementsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== ОБЗОР =====
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> with ReloadWhenVisible {
  final _service = WorkoutService();
  bool _isLoading = true;
  int _selectedPeriodDays = 0;

  int _totalWorkouts = 0;
  double _totalVolume = 0;
  int _totalReps = 0;
  int _totalDuration = 0;
  // Ключ — WorkoutService.exerciseKey (одно упражнение на разных языках — одна строка)
  List<MapEntry<String, double>> _topExercises = [];
  Map<String, double> _records = {};
  // Ключ → самое новое сохранённое название (подпись, если шаблона нет в каталоге)
  Map<String, String> _latestNames = {};
  bool _showAllTop = false;
  bool _showAllRecords = false;
  // Вкладка карточки «Топ-5 | Рекорды», пока приложение запущено (как на «Программах»).
  // static — переживает пересборку вкладок при смене языка. 0 = Топ-5.
  static int _savedListTab = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    // Данные тренировок изменились (например, в «Моих упражнениях») — перечитываем
    _service.dataChanged.addListener(onWorkoutDataChanged);
  }

  @override
  void dispose() {
    _service.dataChanged.removeListener(onWorkoutDataChanged);
    super.dispose();
  }

  // Изменение данных: видимая вкладка перечитывает сразу, скрытая — при показе
  @override
  void reloadVisibleData() => _loadStatistics(showSpinner: false);

  Future<void> _loadStatistics({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);

    final allWorkouts = await _service.getCompletedWorkouts();

    final List<Workout> workouts;
    if (_selectedPeriodDays == 0) {
      workouts = allWorkouts;
    } else {
      final cutoff =
          DateTime.now().subtract(Duration(days: _selectedPeriodDays));
      workouts = allWorkouts.where((w) {
        final d = DateTime.tryParse(w.finishedAt ?? w.date);
        return d != null && d.isAfter(cutoff);
      }).toList();
    }

    double volume = 0;
    int reps = 0;
    int duration = 0;
    final Map<String, double> exerciseVolumes = {};

    for (final workout in workouts) {
      duration += workout.duration ?? 0;
      for (final exercise in workout.exercises) {
        for (final set in exercise.sets) {
          if (set.isDone) {
            volume += set.weight * set.reps;
            reps += set.reps;
            final key = _service.exerciseKey(exercise);
            exerciseVolumes[key] =
                (exerciseVolumes[key] ?? 0) + set.weight * set.reps;
          }
        }
      }
    }

    final topAll = (exerciseVolumes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)));

    final records = await _service.getPersonalRecords();
    final latestNames = await _service.getLatestExerciseNames();
    if (!mounted) return;

    setState(() {
      _totalWorkouts = workouts.length;
      _totalVolume = volume;
      _totalReps = reps;
      _totalDuration = duration;
      _topExercises = topAll;
      _records = records;
      _latestNames = latestNames;
      _isLoading = false;
    });
  }

  String _formatVolume(double kg) {
    if (kg >= 1000)
      return '${(kg / 1000).toStringAsFixed(1)}${'workout.t'.tr()}';
    return '${kg.toStringAsFixed(0)}${'workout.kg'.tr()}';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0)
      return '${h}${'workout.hours_short'.tr()} ${m}${'workout.minutes_short'.tr()}';
    return '${m}${'workout.minutes_short'.tr()}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Фильтры
          Row(
            children: [
              _buildFilter(7, 'statistics.last_7_days'.tr()),
              const SizedBox(width: 6),
              _buildFilter(30, 'statistics.last_30_days'.tr()),
              const SizedBox(width: 6),
              _buildFilter(365, 'statistics.last_year'.tr()),
              const SizedBox(width: 6),
              _buildFilter(0, 'statistics.all_time_short'.tr()),
            ],
          ),

          const SizedBox(height: 12),

          // Итоги за период: одна карточка, 4 равные плитки 2×2
          _buildSummaryCard(),

          const SizedBox(height: 12),

          // Топ-5 и Рекорды: одна карточка с переключателем
          _buildListsCard(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFilter(int days, String label) {
    final isActive = _selectedPeriodDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriodDays = days);
          _loadStatistics();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.textMuted,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Подпись выбранного периода (те же ключи, что у фильтров)
  String _periodLabel() {
    switch (_selectedPeriodDays) {
      case 7:
        return 'statistics.last_7_days'.tr();
      case 30:
        return 'statistics.last_30_days'.tr();
      case 365:
        return 'statistics.last_year'.tr();
      default:
        return 'statistics.all_time_short'.tr();
    }
  }

  // Карточка статистики (фон и скругление как у карточек графиков)
  BoxDecoration _cardDecoration() => BoxDecoration(
        color: AppColors.chartCard,
        borderRadius: BorderRadius.circular(14),
      );

  // Заголовок карточки — стиль заголовков карточек графиков («ПРОГРЕСС УПРАЖНЕНИЙ»)
  Widget _buildCardTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.chartText,
        fontSize: 11,
        letterSpacing: 1.5,
      ),
    );
  }

  static const double _tileGap = 8;
  static const double _tilePadding = 8;
  static const double _tileIconBox = 26;
  static const double _tileIconGap = 6;
  static const double _valueFontSize = 18;
  static const double _labelFontSize = 11;

  // Размер шрифта, при котором самый широкий из текстов влезает в ширину —
  // один на все 4 плитки, чтобы значения (и подписи) были одинаковыми.
  double _uniformFontSize(BuildContext context, List<String> texts,
      double maxSize, FontWeight weight, double width) {
    final base = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    double widest = 0;
    for (final t in texts) {
      final painter = TextPainter(
        text: TextSpan(
            text: t,
            style: base.copyWith(fontSize: maxSize, fontWeight: weight)),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
    }
    if (widest <= width || widest == 0) return maxSize;
    // Небольшой запас на округление при отрисовке
    return maxSize * (width / widest) * 0.98;
  }

  Widget _buildSummaryCard() {
    final stats = [
      (
        Icons.fitness_center,
        '$_totalWorkouts',
        'statistics.stat_workouts'.tr(),
        AppColors.count
      ),
      (
        Icons.monitor_weight,
        _formatVolume(_totalVolume),
        'statistics.stat_volume'.tr(),
        AppColors.volume
      ),
      (
        Icons.repeat,
        '$_totalReps',
        'statistics.stat_reps'.tr(),
        AppColors.reps
      ),
      (
        Icons.timer,
        _formatDuration(_totalDuration),
        'statistics.stat_time'.tr(),
        AppColors.duration
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
              '${'statistics.summary_total'.tr()} · ${_periodLabel()}'),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            // Все плитки одной ширины → одна ширина под текст для всех
            final tileWidth = (constraints.maxWidth - _tileGap) / 2;
            final textWidth =
                tileWidth - _tilePadding * 2 - _tileIconBox - _tileIconGap;
            final valueSize = _uniformFontSize(
                context,
                stats.map((e) => e.$2).toList(),
                _valueFontSize,
                FontWeight.bold,
                textWidth);
            final labelSize = _uniformFontSize(
                context,
                stats.map((e) => e.$3).toList(),
                _labelFontSize,
                FontWeight.normal,
                textWidth);

            Widget tile(int i) {
              final (icon, value, label, color) = stats[i];
              return Expanded(
                child: _buildStatTile(
                    icon, value, label, color, valueSize, labelSize),
              );
            }

            return Column(
              children: [
                Row(children: [
                  tile(0),
                  const SizedBox(width: _tileGap),
                  tile(1)
                ]),
                const SizedBox(height: _tileGap),
                Row(children: [
                  tile(2),
                  const SizedBox(width: _tileGap),
                  tile(3)
                ]),
              ],
            );
          }),
        ],
      ),
    );
  }

  // Плитка итога: цветная иконка слева, значение крупно, короткая подпись под ним.
  // Размеры шрифтов приходят общими на все 4 плитки — высота у всех одинаковая.
  Widget _buildStatTile(IconData icon, String value, String label, Color color,
      double valueSize, double labelSize) {
    return Container(
      padding: const EdgeInsets.all(_tilePadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceInset,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: _tileIconBox,
            height: _tileIconBox,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: _tileIconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                      color: color,
                      fontSize: valueSize,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: labelSize),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Одна карточка на всю ширину: переключатель «Топ-5 | Рекорды» и выбранный список
  Widget _buildListsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedTabSwitch(
            options: [
              SegmentedTabOption('statistics.tab_top'.tr()),
              SegmentedTabOption('statistics.tab_records'.tr()),
            ],
            selectedIndex: _savedListTab,
            onSelected: (i) => setState(() => _savedListTab = i),
            padding: const EdgeInsets.only(bottom: 8),
            unselectedColor: AppColors.surfaceInset,
          ),
          if (_savedListTab == 0) _buildTop() else _buildRecords(),
        ],
      ),
    );
  }

  // Строка списка: название на всю ширину (до 3 строк), ⓘ и значение справа.
  // Минимальная высота = область нажатия ⓘ, чтобы строки были одинаковыми.
  Widget _buildListRow(
      {Widget? leading, required String key, required Widget value}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 8)],
            Expanded(
              child: Text(exerciseKeyLabel(context, key, _latestNames),
                  style:
                      const TextStyle(color: AppColors.textSoft, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3),
            ),
            ExerciseInfoButton(templateId: key, name: _latestNames[key]),
            value,
          ],
        ),
      ),
    );
  }

  Widget _buildMoreToggle(bool showAll, int hiddenCount, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          showAll
              ? 'progress.show_less'.tr()
              : 'progress.show_more'.tr(namedArgs: {'count': '$hiddenCount'}),
          style: const TextStyle(color: AppColors.accent, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildEmptyList() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text('statistics.no_exercises'.tr(),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    );
  }

  Widget _buildTop() {
    final medals = [
      AppColors.medalGold,
      AppColors.medalSilver,
      AppColors.medalBronze,
    ];

    if (_topExercises.isEmpty) return _buildEmptyList();
    final visible =
        _showAllTop ? _topExercises : _topExercises.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visible.asMap().entries.map((entry) {
          final i = entry.key;
          final ex = entry.value;
          final color = i < 3 ? medals[i] : AppColors.medalNone;
          return _buildListRow(
            leading: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            key: ex.key,
            value: Text(_formatVolume(ex.value),
                style: const TextStyle(
                    color: AppColors.volume,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          );
        }),
        if (_topExercises.length > 5)
          _buildMoreToggle(_showAllTop, _topExercises.length - 5,
              () => setState(() => _showAllTop = !_showAllTop)),
      ],
    );
  }

  Widget _buildRecords() {
    final allRecords = _records.entries.toList();
    if (allRecords.isEmpty) return _buildEmptyList();
    final visible = _showAllRecords ? allRecords : allRecords.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visible.map((entry) => _buildListRow(
              key: entry.key,
              value: Text('${entry.value} ${'workout.kg'.tr()}',
                  style: const TextStyle(
                      color: AppColors.record,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            )),
        if (allRecords.length > 5)
          _buildMoreToggle(_showAllRecords, allRecords.length - 5,
              () => setState(() => _showAllRecords = !_showAllRecords)),
      ],
    );
  }
}
