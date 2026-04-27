import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'progress_page.dart';
import '../services/workout_service.dart';
import '../models/workout_models.dart';

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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Шапка
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bar_chart,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'statistics.title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Табы
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: [
                    Tab(text: 'statistics.overview'.tr()),
                    Tab(text: 'statistics.charts'.tr()),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Контент табов
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Таб 1 — Обзор (бывшая статистика)
                  const _OverviewTab(),
                  // Таб 2 — Графики (бывший прогресс)
                  const ProgressPage(),
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

class _OverviewTabState extends State<_OverviewTab> {
  final _service = WorkoutService();
  bool _isLoading = true;
  int _selectedPeriodDays = 0;

  int _totalWorkouts = 0;
  double _totalVolume = 0;
  int _totalReps = 0;
  int _totalDuration = 0;
  List<MapEntry<String, double>> _topExercises = [];
  Map<String, double> _records = {};
  bool _showAllTop = false;
  bool _showAllRecords = false;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

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
            exerciseVolumes[exercise.name] =
                (exerciseVolumes[exercise.name] ?? 0) + set.weight * set.reps;
          }
        }
      }
    }

    final topAll = (exerciseVolumes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)));

    final records = await _service.getPersonalRecords();

    setState(() {
      _totalWorkouts = workouts.length;
      _totalVolume = volume;
      _totalReps = reps;
      _totalDuration = duration;
      _topExercises = topAll;
      _records = records;
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
          child: CircularProgressIndicator(color: Color(0xFFF97316)));
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

          // 4 карточки
          Row(
            children: [
              _buildStatCard(Icons.fitness_center, '$_totalWorkouts',
                  'statistics.total_workouts'.tr(), const Color(0xFFF97316)),
              const SizedBox(width: 8),
              _buildStatCard(Icons.monitor_weight, _formatVolume(_totalVolume),
                  'statistics.total_volume'.tr(), const Color(0xFF34D399)),
              const SizedBox(width: 8),
              _buildStatCard(Icons.repeat, '$_totalReps',
                  'statistics.total_reps'.tr(), const Color(0xFF818CF8)),
              const SizedBox(width: 8),
              _buildStatCard(Icons.timer, _formatDuration(_totalDuration),
                  'statistics.total_time'.tr(), const Color(0xFF60A5FA)),
            ],
          ),

          const SizedBox(height: 12),

          // Топ и Рекорды
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTop()),
                const SizedBox(width: 8),
                Expanded(child: _buildRecords()),
              ],
            ),
          ),

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
            color: isActive ? const Color(0xFFF97316) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTop() {
    final medals = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
      const Color(0xFF374151),
      const Color(0xFF374151),
    ];

    final visible =
        _showAllTop ? _topExercises : _topExercises.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text('statistics.top_exercises'.tr().replaceAll('🏆 ', ''),
                  style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 10),
          if (_topExercises.isEmpty)
            Text('statistics.no_exercises'.tr(),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11))
          else ...[
            ...visible.asMap().entries.map((entry) {
              final i = entry.key;
              final ex = entry.value;
              final color = i < 3 ? medals[i] : const Color(0xFF374151);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                      child: Center(
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(ex.key,
                          style: const TextStyle(
                              color: Color(0xFFE2E8F0), fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ),
                    Text(_formatVolume(ex.value),
                        style: const TextStyle(
                            color: Color(0xFFF97316),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
            if (_topExercises.length > 5)
              GestureDetector(
                onTap: () => setState(() => _showAllTop = !_showAllTop),
                child: Text(
                  _showAllTop
                      ? 'progress.show_less'.tr()
                      : 'progress.show_more'.tr(
                          namedArgs: {'count': '${_topExercises.length - 5}'}),
                  style:
                      const TextStyle(color: Color(0xFFF97316), fontSize: 11),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecords() {
    final allRecords = _records.entries.toList();
    final visible = _showAllRecords ? allRecords : allRecords.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text('statistics.records'.tr(),
                  style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 10),
          if (allRecords.isEmpty)
            Text('statistics.no_exercises'.tr(),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11))
          else ...[
            ...visible.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(entry.key,
                          style: const TextStyle(
                              color: Color(0xFFE2E8F0), fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ),
                    Text('${entry.value} ${'workout.kg'.tr()}',
                        style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
            if (allRecords.length > 5)
              GestureDetector(
                onTap: () => setState(() => _showAllRecords = !_showAllRecords),
                child: Text(
                  _showAllRecords
                      ? 'progress.show_less'.tr()
                      : 'progress.show_more'
                          .tr(namedArgs: {'count': '${allRecords.length - 5}'}),
                  style:
                      const TextStyle(color: Color(0xFF34D399), fontSize: 11),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
