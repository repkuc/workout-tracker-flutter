// Подключаем базовые виджеты Flutter.
import 'package:flutter/material.dart';

// Подключаем easy_localization для переводов.
import 'package:easy_localization/easy_localization.dart';

// Подключаем модель программы.
import '../models/program_models.dart';

// Подключаем сервис программ — чтобы заново загрузить программу по ID
// (на случай если что-то изменилось, например через другой экран).
import '../services/program_service.dart';

// Подключаем сервис тренировок — он нам нужен чтобы создать
// настоящую Workout на основе шаблона ProgramWorkout.
import '../services/workout_service.dart';

// Подключаем редактор тренировки — на него мы перейдём после того как
// создадим Workout из шаблона программы.
import 'workout_editor_page.dart';

class ProgramDetailsPage extends StatefulWidget {
  // Экран получает не саму программу, а только её ID.
  // Это правильный подход — если данные программы изменятся пока
  // пользователь смотрит на этот экран, мы всегда сможем перезагрузить
  // актуальную версию по ID.
  final String programId;

  const ProgramDetailsPage({super.key, required this.programId});

  @override
  State<ProgramDetailsPage> createState() => _ProgramDetailsPageState();
}

class _ProgramDetailsPageState extends State<ProgramDetailsPage> {
  final _programService = ProgramService();
  final _workoutService = WorkoutService();

  // Программа которую мы показываем. null пока не загрузилась.
  TrainingProgram? _program;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgram();
  }

  // Загружаем актуальные данные программы по её ID.
  Future<void> _loadProgram() async {
    final program = await _programService.getProgram(widget.programId);
    setState(() {
      _program = program;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
            : _program == null
                ? Center(
                    child: Text(
                      'programs.not_found'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  )
                : Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildScheduleInfo(),
                              const SizedBox(height: 16),
                              _buildWorkoutsHeader(),
                              const SizedBox(height: 8),
                              ..._program!.workouts.map((w) => _buildWorkoutCard(w)).toList(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  // Шапка с кнопкой назад и названием программы.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _program!.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Блок с расписанием программы (если оно заполнено).
  Widget _buildScheduleInfo() {
    if (_program!.schedule.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'programs.schedule'.tr(),
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          _program!.schedule,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }

  // Заголовок секции со списком тренировок.
  Widget _buildWorkoutsHeader() {
    return Text(
      '${'programs.workouts_in_program'.tr()} (${_program!.workouts.length})',
      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, letterSpacing: 1),
    );
  }

  // Карточка одного тренировочного дня с кнопкой "Начать тренировку".
  Widget _buildWorkoutCard(ProgramWorkout workout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            workout.name,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${workout.exercises.length} ${'programs.exercises_count'.tr()}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _startWorkoutFromTemplate(workout),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(
                'workout.start_timer'.tr(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Главная логика: создать настоящую тренировку (Workout) на основе шаблона дня программы.
  Future<void> _startWorkoutFromTemplate(ProgramWorkout template) async {
    // Создаём новую тренировку через обычный сервис тренировок,
    // используя название дня как название тренировки.
    final workout = await _workoutService.createWorkout(
      date: _workoutService.getTodayDate(),
      name: template.name,
    );

    // Проходим по каждому упражнению-шаблону из программы
    // и добавляем такое же упражнение в реальную тренировку,
    // но пока без подходов — их пользователь заполнит сам во время тренировки.
    for (final exercise in template.exercises) {
      await _workoutService.addExercise(
        workout.id,
        name: exercise.name,
        targetMuscle: exercise.targetMuscle.isNotEmpty
            ? 'workout.muscle_${exercise.targetMuscle}'.tr()
            : '',
      );
    }

    // Переходим в обычный редактор тренировки — дальше всё работает
    // так же как с любой другой тренировкой: подходы, таймер, PR и т.д.
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkoutEditorPage(workoutId: workout.id),
        ),
      );
    }
  }
}