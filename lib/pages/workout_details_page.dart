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

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '$h${'workout.hours_short'.tr()} $m${'workout.minutes_short'.tr()}';
    return '$m${'workout.minutes_short'.tr()}';
  }

  String _formatVolume(double kg) {
    if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)}${'workout.t'.tr()}';
    return '${kg.toStringAsFixed(0)}${'workout.kg'.tr()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
            : _workout == null
                ? Center(child: Text('workout.not_found'.tr(), style: const TextStyle(color: Colors.white)))
                : Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: _workout!.exercises.isEmpty
                            ? _buildEmptyState()
                            : _buildContent(),
                      ),
                      _buildRepeatButton(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    final dateTime = DateTime.tryParse(_workout!.finishedAt ?? _workout!.date);
    final formattedDate = dateTime != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(dateTime)
        : _workout!.date;

    // Считаем статистику
    final totalSets = _workout!.exercises.fold<int>(0, (s, e) => s + e.sets.length);
    final doneSets = _workout!.exercises.fold<int>(0, (s, e) => s + e.sets.where((set) => set.isDone).length);
    final totalReps = _workout!.exercises.fold<int>(0, (s, e) => s + e.sets.where((set) => set.isDone).fold(0, (r, set) => r + set.reps));
    final totalVolume = _workout!.exercises.fold<double>(0, (s, e) => s + e.sets.where((set) => set.isDone).fold(0.0, (v, set) => v + set.weight * set.reps));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(color: const Color(0xFFF97316).withOpacity(0.2), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Назад + название
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _workout!.name,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Дата + время
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                const SizedBox(width: 4),
                Text(formattedDate, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ]),
              if (_workout!.duration != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer, color: Color(0xFF10B981), size: 14),
                  const SizedBox(width: 4),
                  Text(_formatDuration(_workout!.duration!), style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ]),
            ],
          ),

          const SizedBox(height: 12),

          // 4 карточки статистики
          Row(
            children: [
              _buildStatCard('${_workout!.exercises.length}', 'history.exercises'.tr(), const Color(0xFFF97316)),
              const SizedBox(width: 8),
              _buildStatCard('$doneSets/$totalSets', 'history.sets'.tr(), const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _buildStatCard('$totalReps', 'history.reps'.tr(), const Color(0xFF818CF8)),
              const SizedBox(width: 8),
              _buildStatCard(_formatVolume(totalVolume), 'history.volume'.tr(), const Color(0xFF34D399)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workout!.exercises.length,
      itemBuilder: (context, index) {
        return _buildExerciseCard(_workout!.exercises[index]);
      },
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
    final volume = exercise.sets
        .where((s) => s.isDone)
        .fold<double>(0, (sum, s) => sum + s.weight * s.reps);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка упражнения
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fitness_center, color: Color(0xFFF97316), size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    if (exercise.targetMuscle.isNotEmpty)
                      Text(exercise.targetMuscle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  ],
                ),
              ),
              Text(_formatVolume(volume), style: const TextStyle(color: Color(0xFFF97316), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),

          if (exercise.sets.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFF0F172A)),
            const SizedBox(height: 10),

            // Подходы в сетку 2 колонки
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.5,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: exercise.sets.length,
              itemBuilder: (context, index) {
                final set = exercise.sets[index];
                return _buildSetItem(set, index);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSetItem(WorkoutSet set, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: set.isDone ? const Color(0xFF10B981) : const Color(0xFFF97316),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${set.reps} ${'workout.reps'.tr().toLowerCase()}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    decoration: set.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  '${set.weight} ${'workout.kg'.tr()}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text('workout.no_exercises_in_workout'.tr(), style: const TextStyle(color: Color(0xFF64748B))),
    );
  }

  Widget _buildRepeatButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showRepeatWorkoutDialog,
          icon: const Icon(Icons.repeat, size: 20),
          label: Text(
            'workout.repeat_workout'.tr(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Future<void> _showRepeatWorkoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF97316), width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text(
          'workout.repeat_workout_confirm'.tr(),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'workout.repeat_workout_message'.tr(),
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('workout.cancel'.tr(), style: const TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.repeat, size: 16),
            label: Text('history.repeat'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );

    if (result == true) await _copyWorkout();
  }

  Future<void> _copyWorkout() async {
    try {
      final newWorkout = await _service.copyWorkout(widget.workoutId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('workout.workout_copied'.tr()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => WorkoutEditorPage(workoutId: newWorkout.id)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}