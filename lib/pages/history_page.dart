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

// Загрузка тренировок: сначала черновик (если есть), потом завершённые
  Future<void> _loadWorkouts() async {
    final completed = await _service.getCompletedWorkouts(); // Получаем завершённые тренировки
    final draft = await _service.getDraftWorkout();       // Получаем черновик (если есть)

    // Объединяем: сначала черновик (если есть), потом завершённые
    final allWorkouts = <Workout>[]; // Новый список для отображения
    if (draft != null) {
      allWorkouts.add(draft);
    }
    allWorkouts.addAll(completed); // Добавляем завершённые тренировки после черновика
    
    // Обновляем состояние
    setState(() {
      _workouts = allWorkouts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFF374151),
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
      (sum, exercise) =>
          sum +
          exercise.sets.where((s) => s.isDone).fold<double>(
              0.0, (setSum, set) => setSum + (set.weight * set.reps)),
    );

    // ← НОВОЕ: Считаем общие повторения (только выполненные!)
    final totalReps = workout.exercises.fold<int>(
      0,
      (sum, exercise) =>
          sum +
          exercise.sets.where((s) => s.isDone).fold<int>(
                // ← ДОБАВЬ .where((s) => s.isDone)
                0,
                (s, set) => s + set.reps,
              ),
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
  elevation: 2,
  color: isDark ? const Color(0xFF1F2937) : const Color(0xFF374151),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(
      color: workout.finishedAt == null 
          ? const Color(0xFFF97316)  // Яркая оранжевая для черновика
          : const Color(0xFFF97316).withOpacity(0.3), // Тусклая для завершённых
      width: workout.finishedAt == null ? 2 : 1, // Толще для черновика
    ),
  ),
  child: InkWell(
    onTap: () {
      // Если черновик - открываем редактор, иначе детали
      if (workout.finishedAt == null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutEditorPage(workoutId: workout.id),
          ),
        ).then((_) => _loadWorkouts());
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutDetailsPage(workoutId: workout.id),
          ),
        );
      }
    },
    onLongPress: () => _showWorkoutActionsMenu(workout),
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
              
              // НОВОЕ: Бейдж "ЧЕРНОВИК" вместо кнопки повтора
              if (workout.finishedAt == null) 
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'workout.draft'.tr().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else ...[
                // Кнопка повторить (только для завершённых)
                GestureDetector(
                  onTap: () {
                    _showRepeatWorkoutDialog(workout);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.repeat,
                      color: Color(0xFFF97316),
                      size: 24,
                    ),
                  ),
                ),
                // Иконка галочки (только для завершённых)
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
                workout.finishedAt == null 
                    ? 'history.in_progress'.tr() // Покажем "В процессе" для черновика
                    : formattedDate,
                style: TextStyle(
                  color: workout.finishedAt == null 
                      ? const Color(0xFFF97316) 
                      : Colors.grey[400],
                  fontSize: 14,
                  fontWeight: workout.finishedAt == null 
                      ? FontWeight.bold 
                      : FontWeight.normal,
                ),
              ),
              if (formattedTime.isNotEmpty && workout.finishedAt != null) ...[
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

          // Статистика (остаётся без изменений)
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
                Icons.play_arrow,
                'history.reps'.tr(),
                '$totalReps',
              ),
              _buildStatColumn(
                Icons.monitor_weight,
                'history.volume'.tr(),
                _formatVolume(totalVolume),
              ),
              if (workout.duration != null)
                _buildStatColumn(
                  Icons.timer,
                  'workout.duration'.tr(),
                  _formatDuration(workout.duration!),
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
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFF97316), size: 18),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

// Показать диалог подтверждения копирования (компактный для истории)
  Future<void> _showRepeatWorkoutDialog(Workout workout) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFF97316),
            width: 2,
          ),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.repeat,
              color: Color(0xFFF97316),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'workout.repeat_workout_confirm'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'workout.repeat_workout_message'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // Название тренировки
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.repeat, size: 20),
            label: Text('history.repeat'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _copyWorkout(workout.id);
    }
  }

// Скопировать тренировку
  Future<void> _copyWorkout(String workoutId) async {
    // Показываем индикатор
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text('workout.copy_in_progress'.tr()),
            ],
          ),
          backgroundColor: const Color(0xFFF97316),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      final newWorkout = await _service.copyWorkout(workoutId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('workout.workout_copied'.tr())),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // Открываем редактор новой тренировки
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutEditorPage(workoutId: newWorkout.id),
          ),
        ).then((_) {
          // Обновляем список истории когда вернёмся
          _loadWorkouts();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Показать меню действий для тренировки (долгое нажатие)
  Future<void> _showWorkoutActionsMenu(Workout workout) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.fitness_center,
                    color: Color(0xFFF97316),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      workout.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFF97316), height: 1),

            // Кнопка "Повторить"
            ListTile(
              leading: const Icon(
                Icons.repeat,
                color: Color(0xFFF97316),
              ),
              title: Text(
                'history.repeat'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // Закрываем меню
                _showRepeatWorkoutDialog(workout);
              },
            ),

            // Кнопка "Удалить"
            ListTile(
              leading: const Icon(
                Icons.delete,
                color: Colors.red,
              ),
              title: Text(
                'workout.delete_workout'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // Закрываем меню
                _showDeleteWorkoutDialog(workout);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

// Показать диалог подтверждения удаления тренировки
  Future<void> _showDeleteWorkoutDialog(Workout workout) async {
    // Считаем статистику для показа
    final totalExercises = workout.exercises.length;
    final totalSets = workout.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Colors.red, // ← Красная рамка
            width: 2,
          ),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_rounded,
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'workout.delete_workout_confirm'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'workout.delete_workout_message'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // Показываем что удаляем
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${totalExercises} ${'history.exercises'.tr().toLowerCase()}, ${totalSets} ${'history.sets'.tr().toLowerCase()}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, // ← Красная кнопка
              foregroundColor: Colors.white,
            ),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteWorkout(workout.id);
    }
  }

// Удалить тренировку
  Future<void> _deleteWorkout(String workoutId) async {
    final success = await _service.deleteWorkout(workoutId);

    if (success) {
      await _loadWorkouts(); // ← Обновляем список

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('workout.workout_deleted'.tr())),
              ],
            ),
            backgroundColor: Colors.red, // ← Красный для удаления
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Форматировать длительность (секунды → ЧЧ:ММ или ММ:СС)
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}${'workout.hours_short'.tr()} ${minutes}${'workout.minutes_short'.tr()}';
    } else {
      return '${minutes}${'workout.minutes_short'.tr()}';
    }
  }

  // Форматировать объём (кг или тонны)
String _formatVolume(double kg) {
  if (kg < 1000) {
    return '${kg.toStringAsFixed(1)} ${'workout.kg'.tr()}';
  } else if (kg < 10000) {
    return '${kg.toStringAsFixed(0)} ${'workout.kg'.tr()}';
  } else {
    final tons = kg / 1000;
    return '${tons.toStringAsFixed(1)} ${'workout.t'.tr()}';
  }
}
}
