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

  // Статистика
  int _totalWorkouts = 0;
  double _totalVolume = 0;
  int _totalReps = 0;
  int _totalDuration = 0;
  List<MapEntry<String, double>> _topExercises = [];
  int _selectedPeriodDays = 0; // 0 - all time, 7 - week, 30 - month

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final allWorkouts = await _service.getCompletedWorkouts();

    // Фильтруем по периоду
    final List<Workout> workouts;
    if (_selectedPeriodDays == 0) {
      workouts = allWorkouts;
    } else {
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: _selectedPeriodDays));

      workouts = allWorkouts.where((w) {
        final workoutDate = DateTime.tryParse(w.finishedAt ?? w.date);
        return workoutDate != null && workoutDate.isAfter(cutoffDate);
      }).toList();
    }

    int workoutCount = 0;
    double volume = 0;
    int reps = 0;
    int duration = 0;

    for (final workout in workouts) {
      workoutCount++;

      // Объём и повторения
      for (final exercise in workout.exercises) {
        for (final set in exercise.sets) {
          if (set.isDone) {
            volume += set.weight * set.reps;
            reps += set.reps;
          }
        }
      }

      // Длительность
      if (workout.duration != null) {
        duration += workout.duration!;
      }
    }

    // ← НОВОЕ: Считаем объём по упражнениям
    final Map<String, double> exerciseVolumes = {};

    for (final workout in workouts) {
      // Проходим по всем тренировкам
      for (final exercise in workout.exercises) {
        // Проходим по упражнениям в тренировке
        final exerciseName = exercise.name; // Получаем название упражнения
        double exerciseVolume = 0; // Считаем объём для этого упражнения

        for (final set in exercise.sets) {
          // Проходим по сетам упражнения
          if (set.isDone) {
            // Учитываем только выполненные сеты
            exerciseVolume += set.weight *
                set.reps; // Добавляем объём сета к общему объёму упражнения
          }
        }
        exerciseVolumes[exerciseName] = (exerciseVolumes[exerciseName] ?? 0) +
            exerciseVolume; // Суммируем объём по упражнениям
      }
    }

    // Сортируем и берём топ-5
    final sortedExercises = exerciseVolumes.entries.toList()
      ..sort((a, b) =>
          b.value.compareTo(a.value)); // Сортируем по объёму (убывание)
    final top5 = sortedExercises.take(5).toList(); // Берём топ-5

    setState(() {
      _totalWorkouts = workoutCount;
      _totalVolume = volume;
      _totalReps = reps;
      _totalDuration = duration;
      _topExercises = top5;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('statistics.title'.tr()),
        backgroundColor: const Color(0xFF1F2937),
      ),
      body: Container(
        color: const Color(0xFF1F2937), // ← ДОБАВЬ темный фон
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'statistics.all_time'.tr(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ← НОВОЕ: Кнопки фильтров периодов
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildPeriodButton(
                                  7, 'statistics.last_7_days'.tr()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildPeriodButton(
                                  30, 'statistics.last_30_days'.tr()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPeriodButton(
                                  365, 'statistics.last_year'.tr()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildPeriodButton(
                                  0, 'statistics.all_time_short'.tr()),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Карточки со статистикой
                    _buildStatCard(
                      Icons.fitness_center,
                      'statistics.total_workouts'.tr(),
                      '$_totalWorkouts',
                      const Color(0xFFF97316),
                    ),

                    _buildStatCard(
                      Icons.monitor_weight,
                      'statistics.total_volume'.tr(),
                      _formatVolume(_totalVolume),
                      const Color(0xFF10B981),
                    ),

                    _buildStatCard(
                      Icons.play_arrow,
                      'statistics.total_reps'.tr(),
                      '$_totalReps',
                      const Color(0xFF3B82F6),
                    ),

                    _buildStatCard(
                      Icons.timer,
                      'statistics.total_time'.tr(),
                      _formatDuration(_totalDuration),
                      const Color(0xFFA855F7),
                    ),
                    // ← НОВОЕ: Топ-5 упражнений
                    const SizedBox(height: 24),

                    Text(
                      'statistics.top_exercises'.tr(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_topExercises.isEmpty)
                      Card(
                        color: const Color(0xFF1F2937),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'statistics.no_exercises'.tr(),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      ..._topExercises.asMap().entries.map((entry) {
                        final index = entry.key;
                        final exercise = entry.value;
                        return _buildTopExerciseCard(
                          index + 1,
                          exercise.key,
                          exercise.value,
                        );
                      }).toList(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(
      IconData icon, String label, String value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1F2937),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Форматирование объёма с единицами измерения
  String _formatVolume(double kg) {
    if (kg < 1000) {
      return '${kg.toStringAsFixed(1)} ${'workout.kg'.tr()}';
    } else if (kg < 10000) {
      return '${kg.toStringAsFixed(0)} ${'workout.kg'.tr()}';
    } else {
      return '${(kg / 1000).toStringAsFixed(1)} ${'workout.t'.tr()}';
    }
  }

  // Форматирование длительности в часы и минуты
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}ч ${minutes}м';
    } else {
      return '${minutes}м';
    }
  }

// Карточка для топ-5 упражнений
  Widget _buildTopExerciseCard(int rank, String name, double volume) {
    // Иконки медалей для топ-3
    final medalIcons = [
      Icons.emoji_events, // 🥇 Золото
      Icons.emoji_events, // 🥈 Серебро
      Icons.emoji_events, // 🥉 Бронза
    ];

    final medalColors = [
      const Color(0xFFFFD700), // Золотой
      const Color(0xFFC0C0C0), // Серебряный
      const Color(0xFFCD7F32), // Бронзовый
    ];

    final isTopThree = rank <= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF1F2937),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Номер или медаль
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isTopThree
                    ? medalColors[rank - 1].withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isTopThree
                    ? Icon(
                        medalIcons[rank - 1],
                        color: medalColors[rank - 1],
                        size: 24,
                      )
                    : Text(
                        '$rank',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(width: 16),

            // Название упражнения
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Объём
            Text(
              _formatVolume(volume),
              style: TextStyle(
                color: isTopThree
                    ? medalColors[rank - 1]
                    : const Color(0xFFF97316),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Кнопка для выбора периода статистики
  Widget _buildPeriodButton(int days, String label) {
    final isSelected = _selectedPeriodDays == days;

    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedPeriodDays = days;
          _isLoading = true;
        });
        _loadStatistics();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFFF97316) : const Color(0xFF374151),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: isSelected ? 4 : 0,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
