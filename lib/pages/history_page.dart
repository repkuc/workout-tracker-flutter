import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/workout_service.dart';
import '../models/workout_models.dart';
import 'workout_editor_page.dart';
import 'workout_details_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _service = WorkoutService();
  List<Workout> _workouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    final workouts = await _service.getCompletedWorkouts();
    setState(() {
      _workouts = workouts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1F2937),
                    const Color(0xFF374151),
                  ]
                : [
                    const Color(0xFF1F2937),
                    const Color(0xFF374151),
                    const Color(0xFF4B5563),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFF97316),
                        ),
                      )
                    : _workouts.isEmpty
                        ? _buildEmptyState()
                        : _buildWorkoutsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFF97316).withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.history,
            color: Color(0xFFF97316),
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            'history.title'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Пустое состояние
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF97316).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.history,
                size: 64,
                color: Color(0xFFF97316),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'history.no_workouts'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'history.start_first'.tr(),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Список тренировок
  Widget _buildWorkoutsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workouts.length,
      itemBuilder: (context, index) {
        final workout = _workouts[index];
        return _buildWorkoutCard(workout);
      },
    );
  }

  // Карточка одной тренировки
Widget _buildWorkoutCard(Workout workout) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  // Считаем статистику
  final totalExercises = workout.exercises.length;
  final totalSets = workout.exercises.fold<int>(
    0,
    (sum, exercise) => sum + exercise.sets.length,
  );
  final completedSets = workout.exercises.fold<int>(
    0,
    (sum, exercise) => sum + exercise.sets.where((s) => s.isDone).length,
  );
  final totalVolume = workout.exercises.fold<double>(
    0.0,
    (sum, exercise) => sum + exercise.sets
        .where((s) => s.isDone)
        .fold<double>(0.0, (setSum, set) => setSum + (set.weight * set.reps)),
  );

  // Форматируем дату
  final dateTime = DateTime.tryParse(workout.finishedAt ?? workout.date);
  final formattedDate = dateTime != null
      ? DateFormat('dd.MM.yyyy').format(dateTime)
      : workout.date;
  final formattedTime = dateTime != null && workout.finishedAt != null
      ? DateFormat('HH:mm').format(dateTime)
      : '';

  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 4,
    color: isDark ? const Color(0xFF1F2937) : const Color(0xFF374151),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: const Color(0xFFF97316).withOpacity(0.3),
        width: 1,
      ),
    ),
    child: InkWell(
     onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => WorkoutDetailsPage(workoutId: workout.id),
    ),
  );
},
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок: название + дата
            Row(
              children: [
                const Icon(
                  Icons.fitness_center,
                  color: Color(0xFFF97316),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    workout.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Иконка галочки (завершено)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Дата и время
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey[500],
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                if (formattedTime.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.access_time,
                    color: Colors.grey[500],
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formattedTime,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF97316), height: 1),
            const SizedBox(height: 12),
            
            // Статистика
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  Icons.fitness_center,
                  'history.exercises'.tr(),
                  '$totalExercises',
                ),
                _buildStatColumn(
                  Icons.repeat,
                  'history.completed_sets'.tr(),
                  '$completedSets/$totalSets',
                ),
                _buildStatColumn(
                  Icons.monitor_weight,
                  'history.volume'.tr(),
                  '${totalVolume.toStringAsFixed(0)} ${'workout.kg'.tr()}',
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// Вспомогательная функция для колонки статистики
Widget _buildStatColumn(IconData icon, String label, String value) {
  return Column(
    children: [
      Icon(icon, color: const Color(0xFFF97316), size: 20),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
      ),
    ],
  );
}
}