import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/workout_service.dart';
import '../models/workout_models.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final _service = WorkoutService();
  bool _isLoading = true;

  int _totalWorkouts = 0;
  double _totalVolume = 0;
  int _totalReps = 0;
  int _totalDuration = 0;
  List<MapEntry<String, double>> _topExercises = [];
  Map<String, double> _records = {};
  int _selectedPeriodDays = 0;

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
      final cutoff = DateTime.now().subtract(Duration(days: _selectedPeriodDays));
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

    final top5 = (exerciseVolumes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();

    // Рекорды всегда за всё время
    final records = await _service.getPersonalRecords();

    setState(() {
      _totalWorkouts = workouts.length;
      _totalVolume = volume;
      _totalReps = reps;
      _totalDuration = duration;
      _topExercises = top5;
      _records = records;
      _isLoading = false;
    });
  }

  String _formatVolume(double kg) {
    if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)}т';
    return '${kg.toStringAsFixed(0)}кг';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}ч ${m}м';
    return '${m}м';
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
                    child: const Icon(Icons.bar_chart, color: Colors.white, size: 20),
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

            // Фильтры
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
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
            ),

            const SizedBox(height: 12),

            // Контент
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // 4 карточки статистики
                          Row(
                            children: [
                              _buildStatCard(Icons.fitness_center, '$_totalWorkouts', 'statistics.total_workouts'.tr(), const Color(0xFFF97316)),
                              const SizedBox(width: 8),
                              _buildStatCard(Icons.monitor_weight, _formatVolume(_totalVolume), 'statistics.total_volume'.tr(), const Color(0xFF34D399)),
                              const SizedBox(width: 8),
                              _buildStatCard(Icons.repeat, '$_totalReps', 'statistics.total_reps'.tr(), const Color(0xFF818CF8)),
                              const SizedBox(width: 8),
                              _buildStatCard(Icons.timer, _formatDuration(_totalDuration), 'statistics.total_time'.tr(), const Color(0xFF60A5FA)),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Топ-5 и Рекорды рядом
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Топ-5
                                Expanded(child: _buildTop5()),
                                const SizedBox(width: 8),
                                // Рекорды
                                Expanded(child: _buildRecords()),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
            ),
          ],
        ),
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
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
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
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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

  Widget _buildTop5() {
    final medals = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
      const Color(0xFF374151),
      const Color(0xFF374151),
    ];

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
              Text(
                'statistics.top_exercises'.tr().replaceAll('🏆 ', ''),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_topExercises.isEmpty)
            Text(
              'statistics.no_exercises'.tr(),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            )
          else
            ..._topExercises.asMap().entries.map((entry) {
              final i = entry.key;
              final ex = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: medals[i],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ex.key,
                        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    Text(
                      _formatVolume(ex.value),
                      style: const TextStyle(
                        color: Color(0xFFF97316),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecords() {
    final topRecords = _records.entries.take(5).toList();

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
              Text(
                'statistics.records'.tr(),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (topRecords.isEmpty)
            Text(
              'statistics.no_exercises'.tr(),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            )
          else
            ...topRecords.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    Text(
                      '${entry.value} ${'workout.kg'.tr()}',
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}