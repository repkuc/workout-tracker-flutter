import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import '../services/workout_service.dart';
import '../models/workout_models.dart';
import '../pages/workout_editor_page.dart';

class ActiveWorkoutBanner extends StatefulWidget {
  const ActiveWorkoutBanner({super.key});

  @override
  State<ActiveWorkoutBanner> createState() => _ActiveWorkoutBannerState();
}

class _ActiveWorkoutBannerState extends State<ActiveWorkoutBanner> {
  final _service = WorkoutService();
  Workout? _activeWorkout;
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadActiveWorkout();
    // Слушаем изменения данных — обновляемся когда тренировка начинается/заканчивается
    _service.dataChanged.addListener(_loadActiveWorkout);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _service.dataChanged.removeListener(_loadActiveWorkout);
    super.dispose();
  }

  Future<void> _loadActiveWorkout() async {
    final draft = await _service.getDraftWorkout();

    // Показываем баннер только если тренировка начата (startedAt != null)
    if (draft?.startedAt != null) {
      final startTime = DateTime.parse(draft!.startedAt!);
      final elapsed = DateTime.now().difference(startTime).inSeconds
          - draft.totalPausedSeconds;

      setState(() {
        _activeWorkout = draft;
        _elapsedSeconds = elapsed;
      });

      // Запускаем таймер если ещё не запущен
      if (_timer == null) {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) { timer.cancel(); return; }
          if (_activeWorkout?.startedAt != null &&
              _activeWorkout?.pausedAt == null) {
            setState(() => _elapsedSeconds++);
          }
        });
      }
    } else {
      // Нет активной тренировки — скрываем баннер
      _timer?.cancel();
      _timer = null;
      setState(() {
        _activeWorkout = null;
        _elapsedSeconds = 0;
      });
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_activeWorkout == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF10B981).withOpacity(0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Мигающая зелёная точка
          _buildPulseDot(),
          const SizedBox(width: 10),

          // Название тренировки
          Expanded(
            child: Text(
              _activeWorkout!.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Таймер
          Text(
            _formatDuration(_elapsedSeconds),
            style: const TextStyle(
              color: Color(0xFF10B981),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),

          const SizedBox(width: 10),

          // Кнопка открыть
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkoutEditorPage(
                    workoutId: _activeWorkout!.id,
                  ),
                ),
              ).then((_) => _loadActiveWorkout());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF97316), width: 1),
              ),
              child: Text(
                'workout.open'.tr(),
                style: const TextStyle(
                  color: Color(0xFFF97316),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(value),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () => setState(() {}), // перезапускаем анимацию
    );
  }
}