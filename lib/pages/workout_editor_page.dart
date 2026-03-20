import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/workout_service.dart';
import '../models/workout_models.dart';
import 'dart:async';

class WorkoutEditorPage extends StatefulWidget {
  final String workoutId;

  const WorkoutEditorPage({
    super.key,
    required this.workoutId,
  });

  @override
  State<WorkoutEditorPage> createState() => _WorkoutEditorPageState();
}

class _WorkoutEditorPageState extends State<WorkoutEditorPage> {
  final _service = WorkoutService();
  Workout? _workout;
  bool _isLoading = true;

  Map<String, Exercise> _originalExercises =
      {}; // Храним оригинальные упражнения для сравнения

  Timer? _timer; // Таймер для отслеживания длительности тренировки
  int _elapsedSeconds = 0; // Прошедшее время в секундах

  // Контроллеры для формы добавления упражнения
  final _exerciseNameController = TextEditingController();
  final _targetMuscleController = TextEditingController();

  // Контроллеры для формы добавления подхода
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();

  // Контроллер для редактирования названия тренировки
  final _workoutNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWorkout();
  }

  @override
  void dispose() {
    _exerciseNameController.dispose();
    _targetMuscleController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _workoutNameController.dispose();
    _timer?.cancel(); // Останавливаем таймер при уничтожении страницы
    super.dispose();
  }

  // Загрузка тренировки и оригинальных упражнений для сравнения
  Future<void> _loadWorkout() async {
    final workout = await _service.getWorkout(widget.workoutId);

    // Загружаем оригинальные упражнения для сравнения
    final originalExercises = <String, Exercise>{};
    if (workout != null) {
      for (final exercise in workout.exercises) {
        if (exercise.copiedFromExerciseId != null) {
          final original = await _service
              .getOriginalExercise(exercise.copiedFromExerciseId!);
          if (original != null) {
            originalExercises[exercise.id] = original;
          }
        }
      }
    }

    setState(() {
      _workout = workout;
      _originalExercises = originalExercises;
      _isLoading = false;
    });

    // ← НОВОЕ: Если тренировка уже начата - продолжаем таймер
    if (workout?.startedAt != null && _timer == null) {
      final startTime = DateTime.parse(workout!.startedAt!);
      final elapsed = DateTime.now().difference(startTime).inSeconds;
      setState(() {
        _elapsedSeconds = elapsed;
      });

      // Запускаем таймер для обновления UI
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_workout?.startedAt != null) {
          final startTime = DateTime.parse(_workout!.startedAt!);
          final elapsed = DateTime.now().difference(startTime).inSeconds;
          setState(() {
            _elapsedSeconds = elapsed;
          });
        }
      });
    }
  }

  // Запустить таймер тренировки
  Future<void> _startTimer() async {
    // Сохраняем время начала в базу
    await _service.startWorkoutTimer(widget.workoutId);
    await _loadWorkout(); // Перезагружаем тренировку

    // Запускаем таймер UI
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_workout?.startedAt != null) {
        final startTime = DateTime.parse(_workout!.startedAt!);
        final elapsed = DateTime.now().difference(startTime).inSeconds;
        setState(() {
          _elapsedSeconds = elapsed;
        });
      }
    });
  }

// Форматировать время (секунды → ЧЧ:ММ:СС или ММ:СС)
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  // Форматировать объём (кг или тонны)
  String _formatVolume(double kg) {
    if (kg < 1000) {
      // Меньше тонны - показываем кг с одним знаком
      return '${kg.toStringAsFixed(1)} ${'workout.kg'.tr()}';
    } else if (kg < 10000) {
      // 1-10 тонн - показываем кг без дробной
      return '${kg.toStringAsFixed(0)} ${'workout.kg'.tr()}';
    } else {
      // 10+ тонн - показываем в тоннах
      final tons = kg / 1000;
      return '${tons.toStringAsFixed(1)} ${'workout.t'.tr()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Градиентный фон
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
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    )
                  : Column(
                      children: [
                        // Header
                        _buildHeader(),

                        // Контент
                        Expanded(
                          child: _workout!.exercises.isEmpty
                              ? _buildEmptyState()
                              : _buildExercisesList(),
                        ),
                        // Нижние кнопки (Добавить упражнение, Завершить тренировку)
                        _buildBottomButtons(),
                      ],
                    ),
        ),
      ),
    );
  }

  //  Построить заголовок тренировки
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
        children: [
          Row(
            children: [
              // Кнопка назад
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              // Название тренировки
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _workout?.name ?? 'workout.title'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _workout?.date ?? '',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              // Кнопка редактирования названия
              IconButton(
                icon: const Icon(
                  Icons.edit,
                  color: Color(0xFFF97316),
                  size: 24,
                ),
                onPressed: _showEditWorkoutNameDialog,
                tooltip: 'workout.edit_workout_name'.tr(),
              ),
            ],
          ),

          // ← НОВОЕ: Таймер или кнопка запуска
          // ← НОВОЕ: Таймер + объём в одну строку
          const SizedBox(height: 4), // Отступ между названием и таймером
          if (_workout?.startedAt == null)
            // Кнопка "Начать тренировку" (на всю ширину)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startTimer,
                icon: const Icon(Icons.play_arrow, size: 20),
                label: Text(
                  'workout.start_timer'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else
            // Таймер + Объём (50/50)
            Column(
              children: [
                // Таймер (сверху)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6), // ← Уменьшили с 8
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF10B981),
                      width: 1, // ← Уменьшили с 2
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timer,
                        color: Color(0xFF10B981),
                        size: 16, // ← Уменьшили с 18
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_elapsedSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16, // ← Уменьшили с 18
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Объём (снизу)
                Builder(
                  builder: (context) {
                    // Текущий объём всей тренировки (только выполненные подходы!)
                    final currentVolume = _workout!.exercises.fold<double>(
                      0,
                      (sum, ex) =>
                          sum +
                          ex.sets.fold<double>(
                            0,
                            (s, set) =>
                                s + (set.isDone ? set.weight * set.reps : 0),
                          ),
                    );

                    // Прошлый объём (если тренировка скопирована)
                    final previousVolume = _workout!.copiedFromWorkoutId != null
                        ? _originalExercises.values.fold<double>(
                            0,
                            (sum, ex) =>
                                sum +
                                ex.sets.fold<double>(
                                  0,
                                  (s, set) => s + (set.weight * set.reps),
                                ),
                          )
                        : null;

                    final difference = previousVolume != null
                        ? currentVolume - previousVolume
                        : 0;
                    final isIncrease = difference > 0;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6), // ← Уменьшили
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFF97316),
                          width: 1, // ← Уменьшили с 2
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.monitor_weight,
                            color: Color(0xFFF97316),
                            size: 16, // ← Уменьшили
                          ),
                          const SizedBox(width: 8),
                          // Если есть прошлый объём - показываем сравнение
                          if (previousVolume != null) ...[
                            Text(
                              _formatVolume(previousVolume),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12, // ← Уменьшили
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const Icon(Icons.arrow_forward,
                                color: Color(0xFFF97316), size: 12),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            _formatVolume(currentVolume),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14, // ← Уменьшили с 16
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (difference != 0) ...[
                            const SizedBox(width: 4),
                            Icon(
                              isIncrease
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: isIncrease
                                  ? const Color(0xFF10B981)
                                  : Colors.red,
                              size: 12,
                            ),
                            Text(
                              _formatVolume(difference.abs().toDouble()),
                              style: TextStyle(
                                color: isIncrease
                                    ? const Color(0xFF10B981)
                                    : Colors.red,
                                fontSize: 11, // ← Уменьшили
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ), // ← Отступ между таймером и объёмом
        ],
      ),
    );
  }

  // Пустое состояние
  // Пустое состояние (нет упражнений)
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Иконка
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
            // Текст
            Text(
              'workout.no_exercises'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'workout.add_first_exercise'.tr(),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

// Список упражнений
  Widget _buildExercisesList() {
    return Column(
      children: [
        // Скроллящийся список
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _workout!.exercises.length,
            itemBuilder: (context, index) {
              final exercise = _workout!.exercises[index];
              return _buildExerciseCard(exercise);
            },
          ),
        ),
      ],
    );
  }

  // Карточка одного упражнения (сворачиваемая)
  Widget _buildExerciseCard(Exercise exercise) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDark ? const Color(0xFF1F2937) : const Color(0xFF374151),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          // ← Зеленая рамка если завершено
          color: exercise.isCompleted
              ? const Color(0xFF10B981)
              : const Color(0xFFF97316).withOpacity(0.3),
          width: exercise.isCompleted ? 2 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: !exercise.isCompleted, // ← Свернуто если завершено
          tilePadding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 2), // Отступы заголовка
          childrenPadding: const EdgeInsets.only(
              left: 12,
              right: 12,
              top: 0,
              bottom: 12), // Отступы внутри раскрывающейся части
          // Заголовок
          title: Row(
            children: [
              // Иконка + название
              Icon(
                exercise.isCompleted
                    ? Icons.check_circle
                    : Icons.fitness_center,
                color: exercise.isCompleted
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF97316),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  exercise.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: exercise.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              // Кнопка редактирования
              IconButton(
                icon: const Icon(
                  Icons.edit,
                  color: Color(0xFFF97316),
                  size: 16,
                ),
                onPressed: () => _showEditExerciseDialog(exercise),
                tooltip: 'workout.edit_exercise'.tr(),
              ),
            ],
          ),
          children: [
            // Целевая мышца (если есть и не завершено)
            if (exercise.targetMuscle.isNotEmpty && !exercise.isCompleted) ...[
              Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: Colors.grey[500],
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    exercise.targetMuscle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            // Текущий объём упражнения
            // Объём упражнения (с сравнением если скопировано)
            if (exercise.sets.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  // Текущий объём
                  final currentVolume = exercise.sets.fold<double>(
                    0,
                    (sum, s) => sum + (s.isDone ? s.weight * s.reps : 0),
                  );

                  // Оригинальное упражнение (если скопировано)
                  final original = _originalExercises[exercise.id];
                  final previousVolume = original?.sets.fold<double>(
                    0,
                    (sum, s) => sum + (s.weight * s.reps),
                  );

                  // Разница
                  final hasPrevious = previousVolume != null;
                  final difference =
                      hasPrevious ? currentVolume - previousVolume : 0;
                  final isIncrease = difference > 0;
                  //final isDecrease = difference < 0;

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF97316).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: hasPrevious
                        ? Row(
                            children: [
                              const Icon(
                                Icons.monitor_weight,
                                color: Color(0xFFF97316),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _formatVolume(previousVolume),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_forward,
                                  color: Color(0xFFF97316), size: 12),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _formatVolume(currentVolume),
                                  style: const TextStyle(
                                    color: Color(0xFFF97316),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (difference != 0) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  isIncrease
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: isIncrease
                                      ? const Color(0xFF10B981)
                                      : Colors.red,
                                  size: 11,
                                ),
                                Flexible(
                                  child: Text(
                                    _formatVolume(difference.abs().toDouble()),
                                    style: TextStyle(
                                      color: isIncrease
                                          ? const Color(0xFF10B981)
                                          : Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Row(
                            children: [
                              const Icon(
                                Icons.monitor_weight,
                                color: Color(0xFFF97316),
                                size: 12,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${'workout.volume'.tr()}: ',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _formatVolume(currentVolume),
                                style: const TextStyle(
                                  color: Color(0xFFF97316),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],

            // Список подходов
            if (exercise.sets.isNotEmpty) ...[
              if (!exercise.isCompleted)
                const Divider(color: Color(0xFFF97316), height: 1),
              const SizedBox(height: 12),
              ...exercise.sets.asMap().entries.map((entry) {
                final index = entry.key;
                final set = entry.value;
                return _buildSetItem(exercise, set, index);
              }).toList(),
            ],

            // Две кнопки рядом
            const SizedBox(height: 8),
            // Кнопки управления
            Column(
              children: [
                // Первая строка: "Добавить подход" + "+1"
                Row(
                  children: [
                    // Кнопка "Добавить подход"
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddSetDialog(exercise),
                        icon: const Icon(
                          Icons.add,
                          color: Color(0xFFF97316),
                          size: 18,
                        ),
                        label: Text(
                          'workout.add_set_button'.tr(),
                          style: const TextStyle(
                            color: Color(0xFFF97316),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFFF97316),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // НОВОЕ: Кнопка "+1"
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: exercise.sets.isEmpty
                            ? null // Disabled если нет подходов
                            : () => _addOneMoreSet(exercise),
                        child: Text(
                          'workout.add_one_more'.tr(),
                          style: TextStyle(
                            color: exercise.sets.isEmpty
                                ? Colors.grey
                                : const Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: exercise.sets.isEmpty
                                ? Colors.grey
                                : const Color(0xFF10B981),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Вторая строка: "Завершить упражнение"
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleExerciseCompleted(exercise),
                    icon: Icon(
                      exercise.isCompleted ? Icons.undo : Icons.check,
                      size: 18,
                    ),
                    label: Text(
                      exercise.isCompleted
                          ? 'workout.uncomplete_exercise'.tr()
                          : 'workout.complete_exercise'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: exercise.isCompleted
                          ? Colors.grey[700]
                          : const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Элемент списка подходов
  Widget _buildSetItem(Exercise exercise, WorkoutSet set, int index) {
    // Если упражнение завершено - все подходы серые и зачёркнутые
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
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
      child: InkWell(
        onTap: () => _toggleSetDone(exercise.id, set.id, !set.isDone),
        borderRadius: BorderRadius.circular(8),
        onLongPress: () => _showSetActionsMenu(exercise, set, index + 1),
        child: Row(
          children: [
            // Номер подхода
            Container(
              width: 28,
              height: 28,
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
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Повторы и вес
            Expanded(
              child: Text(
                '${set.reps} ${'workout.reps'.tr().toLowerCase()} × ${set.weight} ${'workout.kg'.tr()}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  decoration: set.isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            // Иконка галочки
            Icon(
              set.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: set.isDone ? const Color(0xFF10B981) : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

// Отметить/снять отметку "выполнен"
  Future<void> _toggleSetDone(
      String exerciseId, String setId, bool isDone) async {
    await _service.toggleSetDone(widget.workoutId, exerciseId, setId, isDone);

    // ← НОВОЕ: Автостарт таймера при первой отметке
    if (isDone && _workout?.startedAt == null) {
      // Это первый выполненный подход - запускаем таймер!
      await _startTimer();

      // Показываем уведомление
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('workout.workout_started'.tr()),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    await _loadWorkout();
  }

  // Показать диалог добавления подхода
  Future<void> _showAddSetDialog(Exercise exercise) async {
    // Очищаем поля
    _repsController.clear();
    _weightController.clear();

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
        title: Text(
          'workout.add_set_dialog_title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Поле "Повторы"
            TextField(
              controller: _repsController,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                hintText: 'workout.reps_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                labelText: 'workout.reps'.tr(),
                labelStyle: const TextStyle(color: Color(0xFFF97316)),
                prefixIcon: const Icon(
                  Icons.repeat,
                  color: Color(0xFFF97316),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Поле "Вес"
            TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                hintText: 'workout.weight_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                labelText: 'workout.weight'.tr() + ' (${'workout.kg'.tr()})',
                labelStyle: const TextStyle(color: Color(0xFFF97316)),
                prefixIcon: const Icon(
                  Icons.fitness_center,
                  color: Color(0xFFF97316),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
          // Кнопка "Добавить"
          ElevatedButton(
            onPressed: () {
              // Проверка повторов
              final reps = int.tryParse(_repsController.text.trim());
              if (reps == null || reps <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('workout.reps_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Проверка веса
              final weight = double.tryParse(_weightController.text.trim());
              if (weight == null || weight < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('workout.weight_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            child: Text('workout.add_set_button'.tr()),
          ),
        ],
      ),
    );

    // Если нажали "Добавить"
    if (result == true) {
      await _addSet(exercise.id);
    }
  }

// НОВОЕ: Быстро добавить подход как последний
  Future<void> _addOneMoreSet(Exercise exercise) async {
    if (exercise.sets.isEmpty) return;

    // Берём параметры последнего подхода
    final lastSet = exercise.sets.last;

    // Добавляем через сервис (передаём параметры напрямую)
    await _service.addSet(
      widget.workoutId,
      exercise.id,
      reps: lastSet.reps,
      weight: lastSet.weight,
    );

    // Обновляем
    await _loadWorkout();

    // Показываем уведомление
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${lastSet.reps} reps × ${lastSet.weight} ${'workout.kg'.tr()}',
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

// Добавить подход в базу
  Future<void> _addSet(String exerciseId) async {
    final reps = int.parse(_repsController.text.trim());
    final weight = double.parse(_weightController.text.trim());

    final success = await _service.addSet(
      widget.workoutId,
      exerciseId,
      reps: reps,
      weight: weight,
    );

    if (success) {
      await _loadWorkout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${'workout.add_set_button'.tr()}! $reps × $weight ${'workout.kg'.tr()}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  // Показать диалог добавления упражнения
  Future<void> _showAddExerciseDialog() async {
    // Очищаем поля
    _exerciseNameController.clear();
    _targetMuscleController.clear();

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
        title: Text(
          'workout.add_exercise_dialog_title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Поле "Название упражнения"
            TextField(
              controller: _exerciseNameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151), // Тёмно-серый фон
                hintText: 'workout.exercise_name_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(
                  Icons.fitness_center,
                  color: Color(0xFFF97316),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Поле "Целевая мышца"
            TextField(
              controller: _targetMuscleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151), // Тёмно-серый фон
                hintText: 'workout.target_muscle_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(
                  Icons.radio_button_checked,
                  color: Colors.grey[500],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
          // Кнопка "Добавить"
          ElevatedButton(
            onPressed: () {
              if (_exerciseNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('workout.exercise_name_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: Text('workout.add_exercise'.tr()),
          ),
        ],
      ),
    );

    // Если нажали "Добавить"
    if (result == true) {
      await _addExercise();
    }
  }

// Добавить упражнение в базу
  Future<void> _addExercise() async {
    final name = _exerciseNameController.text.trim();
    final muscle = _targetMuscleController.text.trim();

    final success = await _service.addExercise(
      widget.workoutId,
      name: name,
      targetMuscle: muscle,
    );

    if (success) {
      await _loadWorkout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('$name - ${'workout.add_exercise'.tr().toLowerCase()}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  // Показать диалог редактирования упражнения
  Future<void> _showEditExerciseDialog(Exercise exercise) async {
    // Заполняем поля текущими значениями
    _exerciseNameController.text = exercise.name;
    _targetMuscleController.text = exercise.targetMuscle;

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
        title: Text(
          'workout.edit_exercise_dialog_title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Поле "Название упражнения"
            TextField(
              controller: _exerciseNameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                hintText: 'workout.exercise_name_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(
                  Icons.fitness_center,
                  color: Color(0xFFF97316),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Поле "Целевая мышца"
            TextField(
              controller: _targetMuscleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                hintText: 'workout.target_muscle_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(
                  Icons.radio_button_checked,
                  color: Colors.grey[500],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
          // Кнопка "Сохранить"
          ElevatedButton(
            onPressed: () {
              if (_exerciseNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('workout.exercise_name_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: Text('workout.save'.tr()),
          ),
        ],
      ),
    );

    // Если нажали "Сохранить"
    if (result == true) {
      await _updateExercise(exercise.id);
    }
  }

  // Обновить упражнение
  Future<void> _updateExercise(String exerciseId) async {
    final name = _exerciseNameController.text.trim();
    final muscle = _targetMuscleController.text.trim();

    final success = await _service.updateExercise(
      widget.workoutId,
      exerciseId,
      name: name,
      targetMuscle: muscle,
    );

    if (success) {
      await _loadWorkout(); // ← Перезагружаем тренировку

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('workout.exercise_updated'.tr()),
            backgroundColor: const Color(0xFF10B981), // ← Зелёный (успех)
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Переключить статус завершенности упражнения
  Future<void> _toggleExerciseCompleted(Exercise exercise) async {
    final newStatus = !exercise.isCompleted;

    final success = await _service.toggleExerciseCompleted(
      widget.workoutId,
      exercise.id,
      newStatus,
    );

    if (success) {
      await _loadWorkout(); // ← Перезагружаем тренировку

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus ? Icons.check_circle : Icons.undo,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    newStatus
                        ? 'workout.exercise_completed'.tr()
                        : 'workout.uncomplete_exercise'.tr(),
                  ),
                ),
              ],
            ),
            backgroundColor: newStatus
                ? const Color(0xFF10B981) // Зеленый если завершили
                : const Color(0xFFF97316), // Оранжевый если отменили
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Показать диалог подтверждения удаления подхода
  Future<void> _showDeleteSetDialog(
      Exercise exercise, WorkoutSet set, int setNumber) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Colors.red,
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
                'workout.delete_set_confirm'.tr(),
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
              'workout.delete_set_message'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            // Показываем детали удаляемого подхода
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Номер подхода
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF97316),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$setNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Детали подхода
                  Expanded(
                    child: Text(
                      '${set.reps} ${'workout.reps'.tr().toLowerCase()} × ${set.weight} ${'workout.kg'.tr()}',
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
          // Кнопка "Отмена"
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          // Кнопка "Удалить" (красная)
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );

    // Если подтвердили удаление
    if (result == true) {
      await _deleteSet(exercise.id, set.id);
    }
  }

  // Удалить подход
  Future<void> _deleteSet(String exerciseId, String setId) async {
    final success = await _service.removeSet(
      widget.workoutId,
      exerciseId,
      setId,
    );

    if (success) {
      await _loadWorkout(); // ← Перезагружаем тренировку

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('workout.set_deleted'.tr()),
            backgroundColor: Colors.red, // ← Красный для удаления
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Показать меню выбора действия для подхода
  Future<void> _showSetActionsMenu(
      Exercise exercise, WorkoutSet set, int setNumber) async {
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
                        '$setNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${set.reps} ${'workout.reps'.tr().toLowerCase()} × ${set.weight} ${'workout.kg'.tr()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFF97316), height: 1),

            // Кнопка "Редактировать"
            ListTile(
              leading: Icon(
                Icons.edit,
                color: set.isDone ? Colors.grey : const Color(0xFFF97316),
              ),
              title: Text(
                'workout.edit_set'.tr(),
                style: TextStyle(
                  color: set.isDone ? Colors.grey : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: set.isDone
                  ? Text(
                      'workout.cannot_edit_completed'.tr(),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    )
                  : null,
              enabled: !set.isDone, // ← Отключаем если выполнен
              onTap: set.isDone
                  ? null
                  : () {
                      Navigator.pop(context); // Закрываем меню
                      _showEditSetDialog(exercise, set, setNumber);
                    },
            ),

            // Кнопка "Удалить"
            ListTile(
              leading: const Icon(
                Icons.delete,
                color: Colors.red,
              ),
              title: Text(
                'workout.delete_set'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // Закрываем меню
                _showDeleteSetDialog(exercise, set, setNumber);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Показать диалог редактирования подхода
  Future<void> _showEditSetDialog(
      Exercise exercise, WorkoutSet set, int setNumber) async {
    // Заполняем поля текущими значениями
    _repsController.text = set.reps.toString();
    _weightController.text = set.weight.toString();

    final result = await showDialog<bool>(
      context: context,
     builder: (context) => AlertDialog(
  backgroundColor: const Color(0xFF1F2937),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: const BorderSide(color: Color(0xFFF97316), width: 2),
  ),
  titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
  contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
  actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
  title: Text(
    'workout.edit_set_dialog_title'.tr(),
    style: const TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.bold,
    ),
  ),
  content: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF97316).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF97316), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, color: Color(0xFFF97316), size: 14),
            const SizedBox(width: 6),
            Text(
              '${'workout.add_set_button'.tr()} #$setNumber',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      TextField(
        controller: _repsController,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF374151),
          labelText: 'workout.reps'.tr(),
          labelStyle: const TextStyle(color: Color(0xFFF97316), fontSize: 12),
          prefixIcon: const Icon(Icons.repeat, color: Color(0xFFF97316), size: 16),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _weightController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF374151),
          labelText: '${' workout.weight'.tr()} (${'workout.kg'.tr()})',
          labelStyle: const TextStyle(color: Color(0xFFF97316), fontSize: 12),
          prefixIcon: const Icon(Icons.fitness_center, color: Color(0xFFF97316), size: 16),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ],
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context, false),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        'workout.cancel'.tr(),
        style: TextStyle(color: Colors.grey[400], fontSize: 13),
      ),
    ),
    ElevatedButton(
      onPressed: () {
        final reps = int.tryParse(_repsController.text.trim());
        if (reps == null || reps <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('workout.reps_required'.tr()),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        final weight = double.tryParse(_weightController.text.trim());
        if (weight == null || weight < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('workout.weight_required'.tr()),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        Navigator.pop(context, true);
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontSize: 13),
      ),
      child: Text('workout.save'.tr()),
    ),
  ],
),
    );

    // Если нажали "Сохранить"
    if (result == true) {
      await _updateSet(exercise.id, set.id);
    }
  }

  // Обновить подход
  Future<void> _updateSet(String exerciseId, String setId) async {
    final reps = int.parse(_repsController.text.trim());
    final weight = double.parse(_weightController.text.trim());

    final success = await _service.updateSet(
      widget.workoutId,
      exerciseId,
      setId,
      reps: reps,
      weight: weight,
    );

    if (success) {
      await _loadWorkout(); // ← Перезагружаем тренировку

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('workout.set_updated'.tr()),
            backgroundColor: const Color(0xFF10B981), // ← Зелёный (успех)
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Показать диалог подтверждения завершения тренировки
  Future<void> _showFinishWorkoutDialog() async {
    // ← НОВОЕ: Проверяем незавершенные упражнения
    final incomplete = _getIncompleteExercises();
    if (incomplete.isNotEmpty) {
      // Показываем предупреждение
      final shouldContinue = await _showIncompleteExercisesDialog(incomplete);
      if (!shouldContinue) {
        return; // Пользователь нажал "Вернуться"
      }
    }

    // Считаем текущую статистику
    final totalExercises = _workout!.exercises.length;
    final completedSets = _workout!.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.where((s) => s.isDone).length,
    );
    final totalSets = _workout!.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );
    final totalVolume = _workout!.exercises.fold<double>(
      0,
      (sum, exercise) =>
          sum +
          exercise.sets.fold<double>(
            0,
            (s, set) => s + (set.isDone ? set.weight * set.reps : 0),
          ),
    );

    // ← НОВОЕ: Считаем текущие повторения (только выполненные!)
    final totalReps = _workout!.exercises.fold<int>(
      0,
      (sum, exercise) =>
          sum +
          exercise.sets.fold<int>(
            0,
            (s, set) => s + (set.isDone ? set.reps : 0),
          ),
    );

    // ← НОВОЕ: Считаем прошлую статистику (если скопировано)
    int? previousExercises;
    int? previousSets;
    int? previousReps;
    double? previousVolume;
    int? previousDuration;

    if (_workout!.copiedFromWorkoutId != null &&
        _originalExercises.isNotEmpty) {
      previousExercises = _originalExercises.length;
      previousSets = _originalExercises.values.fold<int>(
        0,
        (sum, ex) => sum + ex.sets.length,
      );
      previousVolume = _originalExercises.values.fold<double>(
        0,
        (sum, ex) =>
            sum +
            ex.sets.fold<double>(
              0,
              (s, set) => s + (set.weight * set.reps),
            ),
      );

      // Загружаем оригинальную тренировку для времени
      final originalWorkout =
          await _service.getWorkout(_workout!.copiedFromWorkoutId!);
      previousDuration = originalWorkout?.duration;

      previousReps = _originalExercises.values.fold<int>(
        0,
        (sum, ex) =>
            sum +
            ex.sets.fold<int>(
              0,
              (s, set) => s + set.reps,
            ),
      );
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFF10B981), // ← Зелёная рамка (успех)
            width: 2,
          ),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Color(0xFF10B981),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'workout.finish_workout_confirm'.tr(),
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
              'workout.finish_workout_message'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // Статистика тренировки
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Упражнения
                  _buildStatRowWithComparison(
                    Icons.fitness_center,
                    'history.exercises'.tr(),
                    totalExercises,
                    previousExercises,
                  ),
                  const SizedBox(height: 2),

                  // Подходы
                  _buildStatRowWithComparison(
                    Icons.repeat,
                    'history.sets'.tr(),
                    totalSets,
                    previousSets,
                  ),
                  const SizedBox(height: 2),

                  // ← НОВОЕ: Повторения
                  _buildStatRowWithComparison(
                    Icons.fitness_center,
                    'history.reps'.tr(),
                    totalReps,
                    previousReps,
                  ),
                  const SizedBox(height: 2),

                  // Объём
                  _buildVolumeComparison(
                    totalVolume,
                    previousVolume,
                  ),
                  const SizedBox(height: 2),

                  // Длительность
                  if (_workout!.startedAt != null)
                    _buildDurationComparison(
                      _elapsedSeconds,
                      previousDuration,
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
          // Кнопка "Завершить" (зелёная)
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981), // ← Зелёный
              foregroundColor: Colors.white,
            ),
            child: Text('workout.finish'.tr()),
          ),
        ],
      ),
    );

    // Если подтвердили завершение
    if (result == true) {
      await _finishWorkout();
    }
  }

  // Проверить есть ли незавершенные упражнения
  List<Map<String, dynamic>> _getIncompleteExercises() {
    final incomplete = <Map<String, dynamic>>[];

    for (final exercise in _workout!.exercises) {
      // Нет подходов
      if (exercise.sets.isEmpty) {
        incomplete.add({
          'name': exercise.name,
          'issue': 'workout.no_sets'.tr(),
        });
        continue;
      }

      // Есть невыполненные подходы
      final incompleteSets = exercise.sets.where((s) => !s.isDone).length;
      if (incompleteSets > 0) {
        incomplete.add({
          'name': exercise.name,
          'issue': '$incompleteSets ${'workout.incomplete_sets'.tr()}',
        });
      }
    }

    return incomplete;
  }

  // Показать диалог о незавершенных упражнениях
  Future<bool> _showIncompleteExercisesDialog(
      List<Map<String, dynamic>> incomplete) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Colors.orange,
            width: 2,
          ),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_rounded,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'workout.incomplete_exercises'.tr(),
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
              'workout.incomplete_exercises_warning'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // Список незавершенных упражнений
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  children: incomplete.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fitness_center,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['issue'],
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
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Кнопка "Вернуться"
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'workout.go_back'.tr(),
              style: const TextStyle(color: Color(0xFFF97316)),
            ),
          ),
          // Кнопка "Всё равно завершить"
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: Text('workout.finish_anyway'.tr()),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // Вспомогательная функция для строки статистики
  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFF97316), size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

// Строка статистики с сравнением (вертикальная)
  Widget _buildStatRowWithComparison(
    IconData icon,
    String label,
    int current,
    int? previous,
  ) {
    final difference = previous != null ? current - previous : null;
    final isIncrease = difference != null && difference > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF10B981), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (previous != null) ...[
                      Text(
                        '$previous',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward,
                          color: Color(0xFFF97316), size: 16),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      '$current',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (difference != null && difference != 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isIncrease
                              ? const Color(0xFF10B981).withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${isIncrease ? '+' : ''}$difference',
                          style: TextStyle(
                            color: isIncrease
                                ? const Color(0xFF10B981)
                                : Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Сравнение объёма (вертикальная)
  Widget _buildVolumeComparison(double current, double? previous) {
    final difference = previous != null ? current - previous : null;
    final isIncrease = difference != null && difference > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.monitor_weight, color: Color(0xFF10B981), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'workout.total_volume_short'.tr(),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (previous != null) ...[
                      Flexible(
                        child: Text(
                          _formatVolume(previous)
                              .replaceAll(' ${'workout.kg'.tr()}', '')
                              .replaceAll(' ${'workout.t'.tr()}', ''),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward,
                          color: Color(0xFFF97316), size: 14),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        _formatVolume(current),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (difference != null && difference != 0) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: isIncrease
                                ? const Color(0xFF10B981).withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${isIncrease ? '+' : ''}${_formatVolume(difference.abs())}',
                            style: TextStyle(
                              color: isIncrease
                                  ? const Color(0xFF10B981)
                                  : Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Сравнение длительности (вертикальная)
  Widget _buildDurationComparison(int currentSeconds, int? previousSeconds) {
    final difference =
        previousSeconds != null ? currentSeconds - previousSeconds : null;
    final isFaster = difference != null && difference < 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: Color(0xFF10B981), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'workout.duration'.tr(),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (previousSeconds != null) ...[
                      Text(
                        _formatDuration(previousSeconds),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward,
                          color: Color(0xFFF97316), size: 16),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _formatDuration(currentSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (difference != null && difference != 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFaster
                              ? const Color(0xFF10B981).withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFaster ? Icons.flash_on : Icons.schedule,
                              size: 14,
                              color: isFaster
                                  ? const Color(0xFF10B981)
                                  : Colors.red,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatDuration(difference.abs()),
                              style: TextStyle(
                                color: isFaster
                                    ? const Color(0xFF10B981)
                                    : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Завершить тренировку
  Future<void> _finishWorkout() async {
    final success = await _service.finishWorkout(widget.workoutId);

    if (success) {
      if (mounted) {
        // Показываем уведомление
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('workout.workout_finished'.tr()),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981), // ← Зелёный
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        // Закрываем экран редактора и возвращаемся на главный экран
        Navigator.pop(context);
      }
    }
  }

  // Показать диалог редактирования названия тренировки
  // Показать диалог редактирования названия тренировки
  Future<void> _showEditWorkoutNameDialog() async {
    // Заполняем поле текущим названием
    _workoutNameController.text = _workout?.name ?? '';

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
        title: Text(
          'workout.edit_workout_name_dialog_title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Иконка
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit,
                color: Color(0xFFF97316),
                size: 32,
              ),
            ),

            // Поле "Название тренировки"
            TextField(
              controller: _workoutNameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                hintText: 'workout.workout_name_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(
                  Icons.fitness_center,
                  color: Color(0xFFF97316),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
          // Кнопка "Сохранить"
          ElevatedButton(
            onPressed: () {
              if (_workoutNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('workout.workout_name_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: Text('workout.save'.tr()),
          ),
        ],
      ),
    );

    // Если нажали "Сохранить"
    if (result == true) {
      await _updateWorkoutName();
    }
  }

// Обновить название тренировки
  Future<void> _updateWorkoutName() async {
    final name = _workoutNameController.text.trim();

    final success = await _service.updateWorkoutMeta(
      widget.workoutId,
      name: name,
    );

    if (success) {
      await _loadWorkout(); // ← Перезагружаем тренировку

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('workout.workout_name_updated'.tr()),
            backgroundColor: const Color(0xFF10B981), // ← Зелёный (успех)
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Нижние кнопки (Добавить упражнение + Завершить тренировку)
  Widget _buildBottomButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(8),
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
        child: Row(
          children: [
            // Кнопка "Добавить упражнение" (оранжевая)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showAddExerciseDialog,
                icon: const Icon(Icons.add_circle, size: 18), // ← Еще меньше
                label: Text(
                  'workout.add_exercise'.tr(),
                  style: const TextStyle(
                    fontSize: 13, // ← Еще меньше
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(
                width: 8), // ← Отступ между кнопками (горизонтальный!)

            // Кнопка "Завершить тренировку" (зелёная)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showFinishWorkoutDialog,
                icon: const Icon(Icons.check_circle, size: 18),
                label: Text(
                  'workout.finish_workout'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
