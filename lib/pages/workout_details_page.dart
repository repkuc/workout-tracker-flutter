import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/workout_service.dart';
import '../models/workout_models.dart';
import 'workout_editor_page.dart';

class WorkoutDetailsPage extends StatefulWidget {
  final String workoutId;

  const WorkoutDetailsPage({
    super.key,
    required this.workoutId,
  });

  @override
  State<WorkoutDetailsPage> createState() => _WorkoutDetailsPageState();
}

class _WorkoutDetailsPageState extends State<WorkoutDetailsPage> {
  final _service = WorkoutService();
  Workout? _workout;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkout();
  }

  Future<void> _loadWorkout() async {
    final workout = await _service.getWorkout(widget.workoutId);
    setState(() {
      _workout = workout;
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFF97316),
                  ),
                )
              : _workout == null
                  ? Center(
                      child: Text(
                        'workout.not_found'.tr(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    )
                  : Column(
                      children: [
                        _buildHeader(),
                        Expanded(
                          child: _workout!.exercises.isEmpty
                              ? _buildEmptyState()
                              : _buildExercisesList(),
                        ),
                        _buildRepeatButton(),
                      ],
                    ),
        ),
      ),
    );
  }

  // Header с информацией о тренировке
  Widget _buildHeader() {
    final dateTime = DateTime.tryParse(_workout!.finishedAt ?? _workout!.date);
    final formattedDate = dateTime != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(dateTime)
        : _workout!.date;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _workout?.name ?? 'workout.title'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
  spacing: 6,
  runSpacing: 4,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    Icon(
      Icons.check_circle,
      color: const Color(0xFF10B981),
      size: 14,
    ),
    Text(
      'workout.completed'.tr(),
      style: TextStyle(color: Colors.grey[400], fontSize: 12),
    ),
    Text(
      formattedDate,
      style: TextStyle(color: Colors.grey[400], fontSize: 12),
    ),
    if (_workout?.duration != null) ...[
      Icon(
        Icons.timer,
        color: const Color(0xFF10B981),
        size: 14,
      ),
      Text(
        _formatDuration(_workout!.duration!),
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
    ]
  ],
),
                  ],
                ),
              ),
            ],
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
                Icons.fitness_center,
                size: 64,
                color: Color(0xFFF97316),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'workout.no_exercises_in_workout'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Список упражнений
  Widget _buildExercisesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workout!.exercises.length,
      itemBuilder: (context, index) {
        final exercise = _workout!.exercises[index];
        return _buildExerciseCard(exercise);
      },
    );
  }

  // Карточка упражнения (только просмотр)
  Widget _buildExerciseCard(Exercise exercise) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDark ? const Color(0xFF1F2937) : const Color(0xFF374151),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFFF97316).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Название упражнения
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
                    exercise.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // Целевая мышца
            if (exercise.targetMuscle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: Colors.grey[500],
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    exercise.targetMuscle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],

            // Список подходов
            if (exercise.sets.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFF97316), height: 1),
              const SizedBox(height: 12),
              ...exercise.sets.asMap().entries.map((entry) {
                final index = entry.key;
                final set = entry.value;
                return _buildSetItem(set, index);
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

// Элемент подхода (только просмотр)
  Widget _buildSetItem(WorkoutSet set, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: set.isDone
            ? const Color(0xFF10B981).withOpacity(0.1)
            : const Color(0xFF4B5563).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: set.isDone
              ? const Color(0xFF10B981)
              : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Номер подхода
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: set.isDone
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF97316),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Повторы и вес
          Expanded(
            child: Text(
              '${set.reps} ${'workout.reps'.tr().toLowerCase()} × ${set.weight} ${'workout.kg'.tr()}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                decoration: set.isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          // Иконка галочки
          Icon(
            set.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: set.isDone ? const Color(0xFF10B981) : Colors.grey,
            size: 24,
          ),
        ],
      ),
    );
  }

  // Показать диалог подтверждения копирования тренировки
  Future<void> _showRepeatWorkoutDialog() async {
    // Считаем статистику для показа
    final totalExercises = _workout!.exercises.length;
    final totalSets = _workout!.exercises.fold<int>(
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
            // Показываем что будет скопировано
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
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
                          _workout!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatInfo(
                        Icons.fitness_center,
                        '$totalExercises',
                        'history.exercises'.tr(),
                      ),
                      _buildStatInfo(
                        Icons.repeat,
                        '$totalSets',
                        'history.sets'.tr(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Кнопка "Отмена"
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          // Кнопка "Повторить"
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

    // Если подтвердили
    if (result == true) {
      await _copyWorkout();
    }
  }

// Скопировать тренировку
  Future<void> _copyWorkout() async {
    // Показываем индикатор загрузки
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
      // Копируем тренировку
      final newWorkout = await _service.copyWorkout(widget.workoutId);

      if (mounted) {
        // Показываем успешное уведомление
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

        // Открываем редактор новой тренировки (заменяем детали)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutEditorPage(workoutId: newWorkout.id),
          ),
        ).then((_) {
          // Когда вернёмся из редактора - закроем детали и вернёмся в историю
          if (mounted) {
            Navigator.pop(context); // Закрываем детали, возвращаемся в историю
          }
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

// Вспомогательная функция для отображения статистики в диалоге
  Widget _buildStatInfo(IconData icon, String value, String label) {
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
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

// Кнопка "Повторить тренировку"
  Widget _buildRepeatButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFF374151),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFF97316).withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showRepeatWorkoutDialog,
            icon: const Icon(Icons.repeat, size: 24),
            label: Text(
              'workout.repeat_workout'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316), // Оранжевая
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  // Вспомогательная функция для форматирования продолжительности
  // Форматировать длительность (секунды → ЧЧ:ММ или ММ:СС)
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}ч ${minutes}м';
    } else {
      return '${minutes}м';
    }
  }
}
