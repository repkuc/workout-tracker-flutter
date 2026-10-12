import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/workout_service.dart';
import '../models/workout_models.dart';
import 'workout_editor_page.dart';
import 'workout_details_page.dart';
import '../theme/app_colors.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _service = WorkoutService();
  List<Workout> _workouts = [];
  bool _isLoading = true;

  // Цвета тренировок — такие же как в календаре и графиках
  final List<Color> _workoutColors = [
    const Color(0xFFF97316),
    const Color(0xFF34D399),
    const Color(0xFF60A5FA),
    const Color(0xFFF472B6),
    const Color(0xFFA78BFA),
    const Color(0xFFFBBF24),
  ];
  Map<String, Color> _nameColors = {};

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
    _service.dataChanged.addListener(_loadWorkouts);
  }

  @override
  void dispose() {
    _service.dataChanged.removeListener(_loadWorkouts);
    super.dispose();
  }

  Future<void> _loadWorkouts() async {
    final completed = await _service.getCompletedWorkouts();
    final draft = await _service.getDraftWorkout();

    final allWorkouts = <Workout>[];
    if (draft != null) allWorkouts.add(draft);
    allWorkouts.addAll(completed);

    // Назначаем цвета по названию
    final Map<String, Color> nameColors = {};
    int colorIndex = 0;
    for (final w in allWorkouts) {
      if (!nameColors.containsKey(w.name)) {
        nameColors[w.name] = _workoutColors[colorIndex % _workoutColors.length];
        colorIndex++;
      }
    }

    setState(() {
      _workouts = allWorkouts;
      _nameColors = nameColors;
      _isLoading = false;
    });
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0)
      return '$h${'workout.hours_short'.tr()} $m${'workout.minutes_short'.tr()}';
    return '$m${'workout.minutes_short'.tr()}';
  }

  String _formatVolume(double kg) {
    if (kg >= 10000)
      return '${(kg / 1000).toStringAsFixed(1)}${'workout.t'.tr()}';
    if (kg >= 1000) return '${kg.toStringAsFixed(0)}${'workout.kg'.tr()}';
    return '${kg.toStringAsFixed(1)}${'workout.kg'.tr()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent))
                  : _workouts.isEmpty
                      ? _buildEmptyState()
                      : _buildWorkoutsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.history, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'history.title'.tr(),
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.history, size: 56, color: AppColors.accent),
          ),
          const SizedBox(height: 16),
          Text('history.no_workouts'.tr(),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 16)),
          const SizedBox(height: 4),
          Text('history.start_first'.tr(),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildWorkoutsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _workouts.length,
      itemBuilder: (context, index) => _buildWorkoutCard(_workouts[index]),
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    final isDraft = workout.finishedAt == null;
    final color = isDraft ? AppColors.draft : _getWorkoutColor(workout);

    final totalSets =
        workout.exercises.fold<int>(0, (s, e) => s + e.sets.length);
    final completedSets = workout.exercises
        .fold<int>(0, (s, e) => s + e.sets.where((set) => set.isDone).length);
    final totalReps = workout.exercises.fold<int>(
        0,
        (s, e) =>
            s +
            e.sets
                .where((set) => set.isDone)
                .fold(0, (r, set) => r + set.reps));
    final totalVolume = workout.exercises.fold<double>(
        0,
        (s, e) =>
            s +
            e.sets
                .where((set) => set.isDone)
                .fold(0.0, (v, set) => v + set.weight * set.reps));

    final dateTime = DateTime.tryParse(workout.finishedAt ?? workout.date);
    final formattedDate = dateTime != null
        ? DateFormat('dd.MM.yyyy').format(dateTime)
        : workout.date;
    final formattedTime = dateTime != null && workout.finishedAt != null
        ? DateFormat('HH:mm').format(dateTime)
        : '';

    return GestureDetector(
      onTap: () {
        if (isDraft) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => WorkoutEditorPage(workoutId: workout.id)),
          ).then((_) => _loadWorkouts());
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    WorkoutDetailsPage(workoutId: workout.id)),
          );
        }
      },
      onLongPress: () => _showWorkoutActionsMenu(workout),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Цветная полоска слева
                Container(width: 4, color: color),

                // Контент
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Название + действия
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                workout.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (isDraft)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.draft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'workout.draft'.tr().toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            else ...[
                              GestureDetector(
                                onTap: () => _showRepeatWorkoutDialog(workout),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.repeat,
                                      color: color, size: 16),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.success.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.check,
                                    color: AppColors.success, size: 16),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Дата и время
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: AppColors.textMuted, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              isDraft
                                  ? 'history.in_progress'.tr()
                                  : formattedDate,
                              style: TextStyle(
                                color:
                                    isDraft ? color : AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: isDraft
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (formattedTime.isNotEmpty && !isDraft) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.access_time,
                                  color: AppColors.textMuted, size: 12),
                              const SizedBox(width: 4),
                              Text(formattedTime,
                                  style: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ],
                        ),

                        // Бейдж "из программы" — показываем только если у тренировки
                        // есть programId (значит она была создана из шаблона программы).
                        // Это чисто информационный бейдж — не кликабельный, просто
                        // показывает контекст откуда взялась эта тренировка.
                        if (workout.programId != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.program.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                      AppColors.program.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.assignment,
                                    color: AppColors.program, size: 10),
                                const SizedBox(width: 4),
                                // Показываем "Название программы · Название дня".
                                // Если по какой-то причине programName не сохранился
                                // (например очень старая тренировка) — используем
                                // только название дня, чтобы не показывать пустоту.
                                Flexible(
                                  child: Text(
                                    workout.programName != null
                                        ? '${workout.programName} · ${workout.programWorkoutName ?? ''}'
                                        : workout.programWorkoutName ??
                                            'programs.title'.tr(),
                                    style: const TextStyle(
                                      color: AppColors.program,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),
                        Divider(height: 1, color: color.withOpacity(0.2)),
                        const SizedBox(height: 10),

                        // Статистика
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStat(
                                '${workout.exercises.length}',
                                'history.exercises'.tr(),
                                AppColors.count),
                            _buildStat(
                                '$completedSets/$totalSets',
                                'history.completed_sets'.tr(),
                                AppColors.success),
                            _buildStat('$totalReps', 'history.reps'.tr(),
                                AppColors.reps),
                            _buildStat(_formatVolume(totalVolume),
                                'history.volume'.tr(), AppColors.volume),
                            if (workout.duration != null)
                              _buildStat(
                                  _formatDuration(workout.duration!),
                                  'workout.duration'.tr(),
                                  AppColors.duration),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _showRepeatWorkoutDialog(Workout workout) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.dialogBorder, width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text('workout.repeat_workout_confirm'.tr(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: Text('workout.repeat_workout_message'.tr(),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('workout.cancel'.tr(),
                style: const TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.repeat, size: 16),
            label: Text('history.repeat'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
    if (result == true) await _copyWorkout(workout.id);
  }

  Future<void> _copyWorkout(String workoutId) async {
    try {
      final newWorkout = await _service.copyWorkout(workoutId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('workout.workout_copied'.tr()),
              backgroundColor: AppColors.success),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  WorkoutEditorPage(workoutId: newWorkout.id)),
        ).then((_) => _loadWorkouts());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _showWorkoutActionsMenu(Workout workout) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(workout.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            ListTile(
              leading: const Icon(Icons.repeat, color: AppColors.accent),
              title: Text('history.repeat'.tr(),
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showRepeatWorkoutDialog(workout);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.danger),
              title: Text('workout.delete_workout'.tr(),
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteWorkoutDialog(workout);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteWorkoutDialog(Workout workout) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.danger, width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text('workout.delete_workout_confirm'.tr(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: Text('workout.delete_workout_message'.tr(),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('workout.cancel'.tr(),
                style: const TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );
    if (result == true) await _deleteWorkout(workout.id);
  }

  Color _getWorkoutColor(Workout workout) {
    if (workout.color != null && workout.color!.isNotEmpty) {
      return Color(int.parse('0xFF${workout.color!.substring(1)}'));
    }
    return _nameColors[workout.name] ?? const Color(0xFFF97316);
  }

  Future<void> _deleteWorkout(String workoutId) async {
    final success = await _service.deleteWorkout(workoutId);
    if (success) {
      await _loadWorkouts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('workout.workout_deleted'.tr()),
              backgroundColor: AppColors.danger),
        );
      }
    }
  }
}
