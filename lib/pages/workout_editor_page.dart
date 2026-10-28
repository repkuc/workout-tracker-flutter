import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/workout_service.dart';
import '../models/workout_models.dart';
import 'dart:async';
import '../models/exercise_template.dart';
import 'exercise_picker_page.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_colors.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/exercise_info_button.dart';
import '../widgets/step_button.dart';
import '../widgets/exercise_goal.dart';

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
  final _audioPlayer = AudioPlayer();
  final _service = WorkoutService();
  Workout? _workout;
  bool _isLoading = true;

  Map<String, Exercise> _originalExercises =
      {}; // Храним оригинальные упражнения для сравнения
  Map<String, double> _personalRecords =
      {}; // Храним личные рекорды для каждого упражнения
  bool _recordsLoaded = false; // Флаг, что рекорды загружены

  Timer? _timer; // Таймер для отслеживания длительности тренировки
  int _elapsedSeconds = 0; // Прошедшее время в секундах
  bool _isPaused = false; // Флаг, что тренировка на паузе
  int _restSeconds = 0; // Сколько секунд уже на паузе
  int _restDuration = 120; // Длительность паузы в секундах (например, 2 минуты)
  Timer? _restTimer; // Таймер для паузы

  // Ключ блока нижних кнопок — по нему узнаём его реальную высоту для отступа SnackBar
  final _bottomButtonsKey = GlobalKey();

  // Отступ для SnackBar, чтобы он появлялся над нижними кнопками, а не перекрывал их.
  // Высоту берём у отрисованного блока (учитывает размер шрифта и т.п.), 120 — запасной вариант.
  EdgeInsets _snackBarMargin() {
    final buttonsHeight = _bottomButtonsKey.currentContext?.size?.height ?? 120;
    return EdgeInsets.fromLTRB(15, 5, 15, buttonsHeight + 10);
  }

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
    _repsController.dispose();
    _weightController.dispose();
    _workoutNameController.dispose();
    _timer?.cancel(); // Останавливаем таймер при уничтожении страницы
    _restTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Загрузка тренировки и оригинальных упражнений для сравнения
  Future<void> _loadWorkout() async {
    // Загрузка личных рекордов (если ещё не загружены)
    if (!_recordsLoaded) {
      _personalRecords = await _service.getPersonalRecords();
      _recordsLoaded = true;
    }

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
        if (_isPaused) return;
        if (_workout?.startedAt != null) {
          final startTime = DateTime.parse(_workout!.startedAt!);
          final elapsed = DateTime.now().difference(startTime).inSeconds -
              (_workout!.totalPausedSeconds);
          setState(() {
            _elapsedSeconds = elapsed;
          });
        }
      });
    }
  }

  // Запустить таймер тренировки
  Future<void> _startTimer() async {
    await _service.startWorkoutTimer(widget.workoutId);
    await _loadWorkout();
    _isPaused = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_isPaused) return; // ← не считаем если пауза
      if (_workout?.startedAt != null) {
        final startTime = DateTime.parse(_workout!.startedAt!);
        final elapsed = DateTime.now().difference(startTime).inSeconds -
            (_workout!.totalPausedSeconds);
        setState(() => _elapsedSeconds = elapsed);
      }
    });
  }

// Пауза/продолжение
  Future<void> _togglePause() async {
    if (_isPaused) {
      // Продолжаем
      await _service.resumeWorkout(widget.workoutId);
      await _loadWorkout();
      setState(() => _isPaused = false);
    } else {
      // Пауза
      await _service.pauseWorkout(widget.workoutId);
      setState(() => _isPaused = true);
    }
  }

// Запустить таймер отдыха
  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() => _restSeconds = _restDuration);

    if (_restDuration == 0) return; // отдых выключен

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _restSeconds--;
        if (_restSeconds <= 0) {
          _restSeconds = 0;
          timer.cancel();
        }
      });

      // Вибрация после setState — чище
      if (_restSeconds <= 0) {
        // 0 — длинная вибрация + звук
        Vibration.vibrate(pattern: [0, 500, 100, 500, 100, 500]);
        _audioPlayer.play(AssetSource('sounds/timer_end_long.mp3')); // ← длинный
      } else if (_restSeconds <= 3) {
        // 3-2-1 — короткая вибрация + звук
        Vibration.vibrate(duration: 80);
        _audioPlayer.play(AssetSource('sounds/timer_end.mp3')); // ← короткий
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() => _restSeconds = 0);
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
    return Scaffold(
      // Градиентный фон
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
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
        color: AppColors.surface.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: AppColors.accent.withOpacity(0.3),
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
                      style: const TextStyle(
                        color: AppColors.textMuted,
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
                  color: AppColors.accent,
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
          if (_workout?.startedAt != null) ...[
            const SizedBox(height: 6),
            // Строка 1: таймер + пауза + объём
            Row(
              children: [
                // Таймер
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isPaused
                          ? AppColors.paused.withOpacity(0.15)
                          : AppColors.active.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isPaused
                            ? AppColors.paused
                            : AppColors.active,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isPaused ? Icons.pause : Icons.play_arrow,
                          color: _isPaused
                              ? AppColors.paused
                              : AppColors.active,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(_elapsedSeconds),
                          style: TextStyle(
                            color: _isPaused
                                ? AppColors.paused
                                : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (_isPaused) ...[
                          const SizedBox(width: 4),
                          Text(
                            'workout.paused'.tr(),
                            style: const TextStyle(
                              color: AppColors.paused,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Кнопка паузы
                GestureDetector(
                  onTap: _togglePause,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _isPaused
                          ? AppColors.active.withOpacity(0.15)
                          : AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isPaused
                            ? AppColors.active
                            : AppColors.accent,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _isPaused ? Icons.play_arrow : Icons.pause,
                      color: _isPaused
                          ? AppColors.active
                          : AppColors.accent,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Объём
                Expanded(
                  flex: 2,
                  child: Builder(
                    builder: (context) {
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
                      final previousVolume =
                          _workout!.copiedFromWorkoutId != null
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
                          : null;
                      final isIncrease = difference != null && difference > 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.volume.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.volume, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monitor_weight,
                                color: AppColors.volume, size: 13),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (previousVolume != null) ...[
                                    Flexible(
                                      child: Text(
                                        _formatVolume(previousVolume),
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 10,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward,
                                        color: AppColors.volume, size: 10),
                                  ],
                                  Flexible(
                                    child: Text(
                                      _formatVolume(currentVolume),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (difference != null &&
                                      difference != 0) ...[
                                    const SizedBox(width: 3),
                                    Text(
                                      '${isIncrease ? '+' : ''}${_formatVolume(difference.abs())}',
                                      style: TextStyle(
                                        color: isIncrease
                                            ? AppColors.improvement
                                            : AppColors.danger,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Строка 2: таймер отдыха (всегда видна)
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _restSeconds > 0
                    ? AppColors.restTimer.withOpacity(0.1)
                    : AppColors.restTimer.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _restSeconds > 0
                      ? AppColors.restTimer
                      : AppColors.restTimer.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.bedtime,
                      color: _restSeconds > 0
                          ? AppColors.restTimer
                          : AppColors.restTimer.withOpacity(0.4),
                      size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'workout.rest_timer'.tr(),
                    style: TextStyle(
                      color: _restSeconds > 0
                          ? AppColors.restTimer
                          : AppColors.restTimer.withOpacity(0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  if (_restSeconds > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(_restSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  // Чипсы
                  Expanded(
                    child: Row(
                      children: [
                        _buildRestChip(30, '30${'workout.seconds_short'.tr()}'),
                        const SizedBox(width: 3),
                        _buildRestChip(60, '1${'workout.minutes_short'.tr()}'),
                        const SizedBox(width: 3),
                        _buildRestChip(120, '2${'workout.minutes_short'.tr()}'),
                        const SizedBox(width: 3),
                        _buildRestChip(180, '3${'workout.minutes_short'.tr()}'),
                        const SizedBox(width: 3),
                        _buildRestChip(0, 'workout.rest_off'.tr()),
                      ],
                    ),
                  ),
                  if (_restSeconds > 0) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _stopRestTimer,
                      child: const Icon(Icons.close,
                          color: AppColors.textMuted, size: 16),
                    ),
                  ],
                ],
              ),
            ),
          ], // ← Отступ между таймером и объёмом
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
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.fitness_center,
                size: 64,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 24),
            // Текст
            Text(
              'workout.no_exercises'.tr(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'workout.add_first_exercise'.tr(),
              style: const TextStyle(
                color: AppColors.textMuted,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          // ← Зеленая рамка если завершено
          color: exercise.isCompleted
              ? AppColors.success
              : AppColors.pending.withOpacity(0.3),
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
                    ? AppColors.success
                    : AppColors.pending,
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
              // Демо упражнения (не сворачивает карточку)
              ExerciseInfoButton(name: exercise.name),
            ],
          ),
          // Цель из программы второй строкой под названием («🎯 4 × 8–12  2 / 4»).
          // У упражнений без плана подзаголовка нет — карточка как раньше.
          subtitle: exercise.hasPlan
              ? Padding(
                  // Отступ = иконка 16 + промежуток 8, чтобы цель стояла под названием
                  padding: const EdgeInsets.only(left: 24, bottom: 2),
                  child: ExerciseGoalLine(exercise: exercise),
                )
              : null,
          children: [
            // Целевая мышца (если есть и не завершено)
            if (exercise.targetMuscle.isNotEmpty && !exercise.isCompleted) ...[
              Row(
                children: [
                  const Icon(
                    Icons.radio_button_checked,
                    color: AppColors.iconNeutral,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    exercise.targetMuscle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
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
                      color: AppColors.volume.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.volume.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: hasPrevious
                        ? Row(
                            children: [
                              const Icon(
                                Icons.monitor_weight,
                                color: AppColors.volume,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _formatVolume(previousVolume),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_forward,
                                  color: AppColors.volume, size: 12),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _formatVolume(currentVolume),
                                  style: const TextStyle(
                                    color: AppColors.volume,
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
                                      ? AppColors.improvement
                                      : AppColors.danger,
                                  size: 11,
                                ),
                                Flexible(
                                  child: Text(
                                    _formatVolume(difference.abs().toDouble()),
                                    style: TextStyle(
                                      color: isIncrease
                                          ? AppColors.improvement
                                          : AppColors.danger,
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
                                color: AppColors.volume,
                                size: 12,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${'workout.volume'.tr()}: ',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _formatVolume(currentVolume),
                                style: const TextStyle(
                                  color: AppColors.volume,
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
                const Divider(color: AppColors.accent, height: 1),
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
                          color: AppColors.accent,
                          size: 18,
                        ),
                        label: Text(
                          'workout.add_set_button'.tr(),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.accent,
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
                                ? AppColors.textMuted
                                : AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: exercise.sets.isEmpty
                                ? AppColors.inactive
                                : AppColors.success,
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
                          ? AppColors.completedButton
                          : AppColors.success,
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
    // ← НОВОЕ: проверяем является ли этот подход новым рекордом
    double maxBefore = _personalRecords[exercise.name] ?? 0;
    for (int i = 0; i < index; i++) {
      final s = exercise.sets[i];
      if (s.isDone && s.weight > maxBefore) maxBefore = s.weight;
    }
    final isPR = set.isDone && set.weight > 0 && set.weight > maxBefore;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: set.isDone
            ? AppColors.success.withOpacity(0.1)
            : AppColors.setRowPending.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: set.isDone
              ? AppColors.success
              : AppColors.inactive.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleSetDone(exercise.id, set.id, !set.isDone),
        borderRadius: BorderRadius.circular(8),
        onLongPress: () => _showSetActionsMenu(exercise, set, index + 1),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: set.isDone
                    ? AppColors.success
                    : AppColors.pending,
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
            // ← НОВОЕ: значок PR
            if (isPR) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppColors.record.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.record, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events,
                        color: AppColors.record, size: 13),
                    SizedBox(width: 3),
                    Text(
                      'PR',
                      style: TextStyle(
                        color: AppColors.record,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Icon(
              set.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: set.isDone ? AppColors.success : AppColors.inactive,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestChip(int seconds, String label) {
    final isSelected = _restDuration == seconds;
    return GestureDetector(
      onTap: () {
        setState(() => _restDuration = seconds);
        if (seconds == 0) {
          _stopRestTimer();
        } else {
          _startRestTimer();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.restTimer.withOpacity(0.2)
              : AppColors.surfaceInset,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? AppColors.restTimer : AppColors.chipBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? AppColors.restTimer : AppColors.textMuted,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

// Отметить/снять отметку "выполнен"
  Future<void> _toggleSetDone(
      String exerciseId, String setId, bool isDone) async {
    // ← НОВОЕ: Проверка на новый личный рекорд (только при отметке "выполнено")
    if (isDone && _workout != null) {
      final exIndex = _workout!.exercises.indexWhere((e) => e.id == exerciseId);
      if (exIndex != -1) {
        final exercise = _workout!.exercises[exIndex];
        final setIndex = exercise.sets.indexWhere((s) => s.id == setId);
        if (setIndex != -1) {
          final set = exercise.sets[setIndex];

          // Максимальный вес ДО этого подхода (рекорд из истории + предыдущие подходы этой тренировки)
          double maxBefore = _personalRecords[exercise.name] ?? 0;
          for (int i = 0; i < setIndex; i++) {
            final s = exercise.sets[i];
            if (s.isDone && s.weight > maxBefore) maxBefore = s.weight;
          }

          if (set.weight > 0 && set.weight > maxBefore) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: AppColors.record),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${'workout.new_record'.tr()} ${exercise.name} — ${set.weight} ${'workout.kg'.tr()}',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.surface,
                  behavior: SnackBarBehavior.floating,
                  margin: _snackBarMargin(),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        }
      }
    }

    await _service.toggleSetDone(widget.workoutId, exerciseId, setId, isDone);

    // Автостарт таймера при первой отметке
    if (isDone && _workout?.startedAt == null) {
      await _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('workout.workout_started'.tr()),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            margin: _snackBarMargin(),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    // Запускаем таймер отдыха если подход выполнен
    if (isDone) {
      _startRestTimer();
    } else {
      _stopRestTimer();
    }

    await _loadWorkout();
  }

  // Показать диалог добавления подхода
  Future<void> _showAddSetDialog(Exercise exercise) async {
    // Если у упражнения уже есть подходы — подставляем значения последнего,
    // иначе поля пустые
    if (exercise.sets.isNotEmpty) {
      final lastSet = exercise.sets.last;
      _repsController.text = lastSet.reps.toString();
      _weightController.text = _formatWeight(lastSet.weight);
    } else {
      _repsController.clear();
      _weightController.clear();
    }

    final result = await _showSetFormDialog(
      title: 'workout.add_set_dialog_title'.tr(),
      confirmLabel: 'workout.add_set_button'.tr(),
    );

    // Если нажали "Добавить"
    if (result) {
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
            '✅ ${lastSet.reps} ${'workout.reps_unit'.tr()} × ${lastSet.weight} ${'workout.kg'.tr()}',
          ),
          backgroundColor: AppColors.success,
          margin: _snackBarMargin(),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

// Добавить подход в базу
  Future<void> _addSet(String exerciseId) async {
    final reps = int.parse(_repsController.text.trim());
    final weight = _parseWeight(_weightController.text)!;

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
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            margin: _snackBarMargin(),
          ),
        );
      }
    }
  }

  // Открыть библиотеку упражнений
  Future<void> _openExercisePicker() async {
    final result = await Navigator.push<PickedExercise>(
      context,
      MaterialPageRoute(builder: (context) => const ExercisePickerPage()),
    );

    if (result != null) {
      await _addExerciseFromTemplate(result.template,
          alreadyInLibrary: result.alreadyInLibrary);
    }
  }

// Добавить упражнение из шаблона библиотеки.
// alreadyInLibrary — введённое название уже было в библиотеке: показываем
// одно сообщение об этом вместо «… добавлено!».
  Future<void> _addExerciseFromTemplate(ExerciseTemplate template,
      {bool alreadyInLibrary = false}) async {
    final lang = context.locale.languageCode;
    final name = template.getName(lang);
    final targetMuscle = template.muscleGroup.isNotEmpty
        ? 'workout.muscle_${template.muscleGroup}'.tr()
        : '';

    final success = await _service.addExercise(
      widget.workoutId,
      name: name,
      targetMuscle: targetMuscle,
      templateId: template.id,
      muscleGroup:
          template.muscleGroup.isNotEmpty ? template.muscleGroup : null,
    );

    if (success) {
      await _loadWorkout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alreadyInLibrary
                ? alreadyInLibraryText(context, template)
                : '$name - ${'workout.add_exercise'.tr().toLowerCase()}!'),
            backgroundColor: alreadyInLibrary
                ? AppColors.snackbarNeutral
                : AppColors.success,
            margin: _snackBarMargin(),
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
                ? AppColors.success // Зеленый если завершили
                : AppColors.pending, // Оранжевый если отменили
            behavior: SnackBarBehavior.floating,
            margin: _snackBarMargin(),
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
      builder: (context) => AppDialog(
        title: 'workout.delete_set_confirm'.tr(),
        icon: Icons.warning_rounded,
        iconColor: AppColors.danger,
        borderColor: AppColors.danger,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'workout.delete_set_message'.tr(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            // Показываем детали удаляемого подхода
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceInset,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Номер подхода
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$setNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Детали подхода
                  Expanded(
                    child: Text(
                      '${set.reps} ${'workout.reps'.tr().toLowerCase()} × ${set.weight} ${'workout.kg'.tr()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
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
          AppDialogCancelButton(
            label: 'workout.cancel'.tr(),
            onPressed: () => Navigator.pop(context, false),
          ),
          // Кнопка "Удалить" (красная)
          AppDialogConfirmButton(
            label: 'workout.delete'.tr(),
            color: AppColors.danger,
            onPressed: () => Navigator.pop(context, true),
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
            backgroundColor: AppColors.snackbarNeutral, // ← Нейтральный: удаление прошло успешно
            behavior: SnackBarBehavior.floating,
            margin: _snackBarMargin(),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Показать меню выбора действия для подхода
  Future<void> _showSetActionsMenu(
      Exercise exercise, WorkoutSet set, int setNumber) async {
    showAppBottomSheet(
      context: context,
      builder: (context) => [
        // Заголовок: номер подхода и «повторы × вес»
        AppSheetHeader(
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: set.isDone ? AppColors.success : AppColors.pending,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$setNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          title:
              '${set.reps} ${'workout.reps'.tr().toLowerCase()} × ${set.weight} ${'workout.kg'.tr()}',
        ),

        // Кнопка "Редактировать"
        ListTile(
          leading: Icon(
            Icons.edit,
            color: set.isDone ? AppColors.inactive : AppColors.accent,
          ),
          title: Text(
            'workout.edit_set'.tr(),
            style: TextStyle(
              color: set.isDone ? AppColors.textMuted : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: set.isDone
              ? Text(
                  'workout.cannot_edit_completed'.tr(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
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
            color: AppColors.danger,
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

      ],
    );
  }

  // Показать диалог редактирования подхода
  Future<void> _showEditSetDialog(
      Exercise exercise, WorkoutSet set, int setNumber) async {
    // Заполняем поля текущими значениями
    _repsController.text = set.reps.toString();
    _weightController.text = _formatWeight(set.weight);

    final result = await _showSetFormDialog(
      title: 'workout.edit_set_dialog_title'.tr(),
      confirmLabel: 'workout.save'.tr(),
      setNumber: setNumber,
    );

    // Если нажали "Сохранить"
    if (result) {
      await _updateSet(exercise.id, set.id);
    }
  }

  // Общий диалог подхода (повторы + вес) для «Добавить подход» и «Изменить подход»,
  // чтобы оба диалога выглядели одинаково. Значения берутся из _repsController / _weightController.
  // setNumber — если задан, сверху показывается плашка «Подход #N».
  Future<bool> _showSetFormDialog({
    required String title,
    required String confirmLabel,
    int? setNumber,
  }) async {
    // Ошибки валидации показываем прямо под полями (SnackBar рисовался бы за фоном диалога)
    String? repsError;
    String? weightError;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          title: title,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (setNumber != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.fitness_center,
                          color: AppColors.accent, size: 14),
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
              // Без autofocus: клавиатура появляется только по тапу в поле,
              // а в зале значения обычно меняют кнопками − / +
              _buildSetStepperRow(
                field: TextField(
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  // Начали печатать — убираем ошибку
                  onChanged: (_) {
                    if (repsError != null) {
                      setDialogState(() => repsError = null);
                    }
                  },
                  decoration: appDialogInputDecoration(
                    labelText: 'workout.reps'.tr(),
                    hintText: 'workout.reps_hint'.tr(),
                    icon: Icons.repeat,
                    errorText: repsError,
                  ),
                ),
                onStep: (delta) {
                  final changed = _stepReps(delta);
                  if (repsError != null) {
                    setDialogState(() => repsError = null);
                  }
                  return changed;
                },
              ),
              const SizedBox(height: 8),
              _buildSetStepperRow(
                field: TextField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (_) {
                    if (weightError != null) {
                      setDialogState(() => weightError = null);
                    }
                  },
                  decoration: appDialogInputDecoration(
                    labelText:
                        '${'workout.weight'.tr()} (${'workout.kg'.tr()})',
                    hintText: 'workout.weight_hint'.tr(),
                    icon: Icons.fitness_center,
                    errorText: weightError,
                  ),
                ),
                onStep: (delta) {
                  final changed = _stepWeight(delta);
                  if (weightError != null) {
                    setDialogState(() => weightError = null);
                  }
                  return changed;
                },
              ),
            ],
          ),
          actions: [
            AppDialogCancelButton(
              label: 'workout.cancel'.tr(),
              onPressed: () => Navigator.pop(context, false),
            ),
            AppDialogConfirmButton(
              label: confirmLabel,
              onPressed: () {
                // Проверка повторов и веса — ошибки показываем под полями
                final reps = int.tryParse(_repsController.text.trim());
                final weight = _parseWeight(_weightController.text);
                setDialogState(() {
                  repsError = (reps == null || reps <= 0)
                      ? 'workout.reps_required'.tr()
                      : null;
                  weightError = (weight == null || weight < 0)
                      ? 'workout.weight_required'.tr()
                      : null;
                });
                if (repsError != null || weightError != null) return;
                Navigator.pop(context, true);
              },
            ),
          ],
        ),
      ),
    );

    return result == true;
  }

  // Шаги кнопок − / + в диалоге подхода
  static const int _repsStep = 1;
  static const double _weightStep = 2.5;

  // Строка поля подхода: [ − ] [ поле ] [ + ].
  // onStep получает -1 или +1 и возвращает true, если значение изменилось.
  Widget _buildSetStepperRow({
    required Widget field,
    required bool Function(int delta) onStep,
  }) {
    return Row(
      // Кнопки остаются на уровне поля, даже когда под ним появляется ошибка
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepButton(
          icon: Icons.remove,
          semanticLabel: 'workout.decrease'.tr(),
          onStep: () => onStep(-1),
        ),
        const SizedBox(width: 4),
        Expanded(child: field),
        const SizedBox(width: 4),
        StepButton(
          icon: Icons.add,
          semanticLabel: 'workout.increase'.tr(),
          onStep: () => onStep(1),
        ),
      ],
    );
  }

  // Вес из поля: принимаем и «.», и «,» (латышская / русская клавиатура)
  double? _parseWeight(String text) {
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  // Вес без лишнего «.0» (50, а не 50.0; 52.5 остаётся 52.5),
  // с округлением до 2 знаков, чтобы не было «хвостов» вроде 21.700000000000003
  String _formatWeight(double weight) {
    final rounded = (weight * 100).round() / 100;
    if (rounded == rounded.roundToDouble()) {
      return rounded.toInt().toString();
    }
    return rounded.toString();
  }

  // Записать текст в поле, курсор — в конец
  void _setFieldText(TextEditingController controller, String text) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  // Повторы ± 1, минимум 1. Пустое поле: «+» ставит 1, «−» ничего не делает.
  bool _stepReps(int delta) {
    final current = int.tryParse(_repsController.text.trim());
    final int next;
    if (current == null) {
      if (delta < 0) return false;
      next = _repsStep;
    } else {
      next = (current + delta * _repsStep).clamp(1, 9999);
    }
    final text = next.toString();
    if (text == _repsController.text) return false;
    _setFieldText(_repsController, text);
    return true;
  }

  // Вес ± 2.5 кг, минимум 0 (вес тела). Ниже 2.5 и «−» → 0.
  // Пустое поле: «+» ставит 2.5, «−» ничего не делает.
  // Нестандартный вес (19.2) просто сдвигается на шаг: 19.2 + 2.5 = 21.7.
  bool _stepWeight(int delta) {
    final current = _parseWeight(_weightController.text);
    final double next;
    if (current == null) {
      if (delta < 0) return false;
      next = _weightStep;
    } else {
      next = (current + delta * _weightStep).clamp(0, 9999).toDouble();
    }
    final text = _formatWeight(next);
    if (text == _weightController.text) return false;
    _setFieldText(_weightController, text);
    return true;
  }

  // Обновить подход
  Future<void> _updateSet(String exerciseId, String setId) async {
    final reps = int.parse(_repsController.text.trim());
    final weight = _parseWeight(_weightController.text)!;

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
            backgroundColor: AppColors.success, // ← Зелёный (успех)
            behavior: SnackBarBehavior.floating,
            margin: _snackBarMargin(),
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
      builder: (context) => AppDialog(
        title: 'workout.finish_workout_confirm'.tr(),
        icon: Icons.check_circle,
        iconColor: AppColors.success,
        borderColor: AppColors.success, // ← Зелёная рамка (успех)
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'workout.finish_workout_message'.tr(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            // Статистика тренировки
            // Упражнения
            _buildStatRowWithComparison(
              Icons.fitness_center,
              'history.exercises'.tr(),
              totalExercises,
              previousExercises,
            ),
            const SizedBox(height: 6),

            // Подходы
            _buildStatRowWithComparison(
              Icons.repeat,
              'history.sets'.tr(),
              totalSets,
              previousSets,
            ),
            const SizedBox(height: 6),

            // Повторения
            _buildStatRowWithComparison(
              Icons.fitness_center,
              'history.reps'.tr(),
              totalReps,
              previousReps,
            ),
            const SizedBox(height: 6),

            // Объём
            _buildVolumeComparison(
              totalVolume,
              previousVolume,
            ),

            // Длительность
            if (_workout!.startedAt != null) ...[
              const SizedBox(height: 6),
              _buildDurationComparison(
                _elapsedSeconds,
                previousDuration,
              ),
            ],
          ],
        ),
        actions: [
          // Кнопка "Отмена"
          AppDialogCancelButton(
            label: 'workout.cancel'.tr(),
            onPressed: () => Navigator.pop(context, false),
          ),
          // Кнопка "Завершить" (зелёная)
          AppDialogConfirmButton(
            label: 'workout.finish'.tr(),
            color: AppColors.success,
            onPressed: () => Navigator.pop(context, true),
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
      builder: (context) => AppDialog(
        title: 'workout.incomplete_exercises'.tr(),
        icon: Icons.warning_rounded,
        iconColor: AppColors.warning,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'workout.incomplete_exercises_warning'.tr(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            // Список незавершенных упражнений
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  children: incomplete.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceInset,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fitness_center,
                            color: AppColors.accent,
                            size: 14,
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
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['issue'],
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ExerciseInfoButton(name: item['name']),
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
          AppDialogCancelButton(
            label: 'workout.go_back'.tr(),
            color: AppColors.accent,
            onPressed: () => Navigator.pop(context, false),
          ),
          // Кнопка "Всё равно завершить"
          AppDialogConfirmButton(
            label: 'workout.finish_anyway'.tr(),
            color: AppColors.success,
            onPressed: () => Navigator.pop(context, true),
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
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (previous != null) ...[
                      Text(
                        '$previous',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward,
                          color: AppColors.accent, size: 12),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '$current',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
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
                              ? AppColors.improvement.withOpacity(0.2)
                              : AppColors.danger.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${isIncrease ? '+' : ''}$difference',
                          style: TextStyle(
                            color: isIncrease
                                ? AppColors.improvement
                                : AppColors.danger,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.monitor_weight, color: AppColors.volume, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'workout.total_volume_short'.tr(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (previous != null) ...[
                      Flexible(
                        child: Text(
                          _formatVolume(previous)
                              .replaceAll(' ${'workout.kg'.tr()}', '')
                              .replaceAll(' ${'workout.t'.tr()}', ''),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward,
                          color: AppColors.volume, size: 12),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        _formatVolume(current),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
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
                                ? AppColors.improvement.withOpacity(0.2)
                                : AppColors.danger.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${isIncrease ? '+' : ''}${_formatVolume(difference.abs())}',
                            style: TextStyle(
                              color: isIncrease
                                  ? AppColors.improvement
                                  : AppColors.danger,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: AppColors.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'workout.duration'.tr(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (previousSeconds != null) ...[
                      Text(
                        _formatDuration(previousSeconds),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward,
                          color: AppColors.accent, size: 12),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _formatDuration(currentSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (difference != null && difference != 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFaster
                              ? AppColors.improvement.withOpacity(0.2)
                              : AppColors.danger.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFaster ? Icons.flash_on : Icons.schedule,
                              size: 12,
                              color: isFaster
                                  ? AppColors.improvement
                                  : AppColors.danger,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatDuration(difference.abs()),
                              style: TextStyle(
                                color: isFaster
                                    ? AppColors.improvement
                                    : AppColors.danger,
                                fontSize: 10,
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
            backgroundColor: AppColors.success, // ← Зелёный
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

    // Ошибку пустого названия показываем прямо под полем
    String? nameError;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          title: 'workout.edit_workout_name_dialog_title'.tr(),
          content: TextField(
            controller: _workoutNameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            // Начали печатать — убираем ошибку
            onChanged: (_) {
              if (nameError != null) {
                setDialogState(() => nameError = null);
              }
            },
            decoration: appDialogInputDecoration(
              labelText: 'workout.workout_name'.tr(),
              hintText: 'workout.workout_name_hint'.tr(),
              icon: Icons.fitness_center,
              errorText: nameError,
            ),
          ),
          actions: [
            AppDialogCancelButton(
              label: 'workout.cancel'.tr(),
              onPressed: () => Navigator.pop(context, false),
            ),
            AppDialogConfirmButton(
              label: 'workout.save'.tr(),
              onPressed: () {
                if (_workoutNameController.text.trim().isEmpty) {
                  setDialogState(() =>
                      nameError = 'workout.workout_name_required'.tr());
                  return;
                }
                Navigator.pop(context, true);
              },
            ),
          ],
        ),
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
            backgroundColor: AppColors.success, // ← Зелёный (успех)
            behavior: SnackBarBehavior.floating,
            margin: _snackBarMargin(),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Нижние кнопки (Добавить упражнение + Завершить тренировку)
  Widget _buildBottomButtons() {
    final isStarted = _workout?.startedAt != null;

    return Container(
      key: _bottomButtonsKey,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.accent.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Кнопка "Добавить упражнение"
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openExercisePicker,
                icon: const Icon(Icons.add_circle,
                    size: 18, color: AppColors.accent),
                label: Text(
                  'workout.add_exercise'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accent, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Кнопка "Начать" → "Завершить"
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isStarted ? _showFinishWorkoutDialog : _startTimer,
                icon: Icon(
                  isStarted ? Icons.check_circle : Icons.play_arrow,
                  size: 20,
                ),
                label: Text(
                  isStarted
                      ? 'workout.finish_workout'.tr()
                      : 'workout.start_timer'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isStarted
                      ? AppColors.accent
                      : AppColors.active,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
