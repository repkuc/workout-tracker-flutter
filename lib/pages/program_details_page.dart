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
// Подключаем модели тренировок, чтобы создать Workout и Exercise.
import '../models/workout_models.dart';

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
  // Map: название дня программы → последняя тренировка этого дня (если была).
  // Загружаем один раз при открытии экрана, чтобы для каждой карточки
  // дня сразу знать показывать "Начать" или "Повторить", не делая
  // отдельный запрос на каждую карточку при построении списка.
  Map<String, Workout> _lastWorkoutsByDay = {};

  @override
  void initState() {
    super.initState();
    _loadProgram();
  }

  // didChangeDependencies вызывается когда страница снова становится видимой —
  // например когда возвращаемся назад после завершения тренировки.
  // Это гарантирует что дата "последний раз" и кнопка "Начать"/"Повторить"
  // всегда актуальны, а не только при первом открытии экрана.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProgram();
  }

  // Загружаем актуальные данные программы по её ID.
  Future<void> _loadProgram() async {
    final program = await _programService.getProgram(widget.programId);

    // Для каждого дня программы ищем — была ли уже тренировка с таким названием
    // дня внутри этой же программы. Складываем результаты в Map для быстрого
    // доступа при отрисовке карточек.
    final Map<String, Workout> lastWorkouts = {};
    if (program != null) {
      for (final workout in program.workouts) {
        final last = await _workoutService.getLastWorkoutForProgramDay(
          program.id,
          workout.name,
        );
        // Добавляем в Map только если действительно нашли прошлую тренировку —
        // иначе для этого дня в Map не будет записи, и мы будем знать
        // что нужно показать "Начать", а не "Повторить".
        if (last != null) {
          lastWorkouts[workout.name] = last;
        }
      }
    }

    setState(() {
      _program = program;
      _lastWorkoutsByDay = lastWorkouts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFF97316)))
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
                              ..._program!.workouts
                                  .map((w) => _buildWorkoutCard(w))
                                  .toList(),
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
          style: const TextStyle(
              color: Color(0xFF64748B), fontSize: 11, letterSpacing: 1),
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
      style: const TextStyle(
          color: Color(0xFF64748B), fontSize: 11, letterSpacing: 1),
    );
  }

  // Карточка одного тренировочного дня с кнопкой "Начать"/"Повторить".
  Widget _buildWorkoutCard(ProgramWorkout workout) {
    // Проверяем — есть ли для этого дня прошлая тренировка.
    final lastWorkout = _lastWorkoutsByDay[workout.name];
    final hasHistory = lastWorkout != null;

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
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${workout.exercises.length} ${'programs.exercises_count'.tr()}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),

          // Показываем дату последнего выполнения, только если она есть.
          if (hasHistory) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF818CF8), size: 12),
                const SizedBox(width: 4),
                Text(
                  '${'programs.last_done'.tr()}: ${_formatLastDate(lastWorkout.finishedAt)}',
                  style:
                      const TextStyle(color: Color(0xFF818CF8), fontSize: 11),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // Если уже есть история — запускаем "Повторить" с подтягиванием
              // прошлых результатов, иначе просто "Начать" с нуля из шаблона.
              onPressed: () => hasHistory
                  ? _repeatWorkoutFromTemplate(workout, lastWorkout)
                  : _startWorkoutFromTemplate(workout),
              icon:
                  Icon(hasHistory ? Icons.repeat : Icons.play_arrow, size: 18),
              label: Text(
                hasHistory
                    ? 'workout.repeat_workout'.tr()
                    : 'workout.start_timer'.tr(),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Форматирует дату последнего выполнения в компактный вид ДД.ММ.ГГГГ.
  String _formatLastDate(String? isoDate) {
    if (isoDate == null) return '';
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  // Начать тренировку с нуля по шаблону программы (когда истории ещё нет).
  Future<void> _startWorkoutFromTemplate(ProgramWorkout template) async {
    // Создаём новую тренировку, сразу указывая programId и название дня —
    // это то самое связывание, которое мы добавили в модель Workout.
    final workout = await _workoutService.createWorkout(
      date: _workoutService.getTodayDate(),
      name: template.name,
      programId: _program!.id,
      programWorkoutName: template.name,
      programName: _program!.name, // Сохраняем "снимок" названия программы
    );

    // Добавляем каждое упражнение из шаблона, пока без подходов.
    for (final exercise in template.exercises) {
      await _workoutService.addExercise(
        workout.id,
        name: exercise.name,
        targetMuscle: exercise.targetMuscle.isNotEmpty
            ? 'workout.muscle_${exercise.targetMuscle}'.tr()
            : '',
      );
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => WorkoutEditorPage(workoutId: workout.id)),
      );
    }
  }

  // Повторить тренировку: берём АКТУАЛЬНЫЙ список упражнений из шаблона программы
  // (а не из старой тренировки), но для каждого упражнения — если оно
  // называется так же как в прошлой тренировке — подтягиваем оттуда подходы
  // (вес и повторы), чтобы не вводить всё заново руками.
  Future<void> _repeatWorkoutFromTemplate(
    ProgramWorkout template,
    Workout lastWorkout,
  ) async {
    // Создаём новую тренировку, снова помечая её как принадлежащую программе.
    final workout = await _workoutService.createWorkout(
      date: _workoutService.getTodayDate(),
      name: template.name,
      programId: _program!.id,
      programWorkoutName: template.name,
      programName: _program!.name, // Сохраняем "снимок" названия программы
      // Сохраняем связь с прошлой тренировкой — это то же поле что
      // используется в обычном copyWorkout(), нужно для сравнения
      // "было / стало" на экране редактора (стрелочки прогресса).
      copiedFromWorkoutId: lastWorkout.id,
    );

    // Идём по упражнениям из АКТУАЛЬНОГО шаблона программы, а не из старой тренировки.
    // Это значит: если упражнение убрали из шаблона — оно не попадёт сюда.
    // Если добавили новое — оно попадёт, просто без истории весов.
    for (final templateExercise in template.exercises) {
      // Пытаемся найти в прошлой тренировке упражнение с таким же названием.
      Exercise? matchingOld;
      try {
        matchingOld = lastWorkout.exercises.firstWhere(
          (e) => e.name == templateExercise.name,
        );
      } catch (e) {
        // Совпадения нет — это новое упражнение в шаблоне, добавим его пустым.
        matchingOld = null;
      }

      // Добавляем упражнение в новую тренировку.
      await _workoutService.addExercise(
        workout.id,
        name: templateExercise.name,
        targetMuscle: templateExercise.targetMuscle.isNotEmpty
            ? 'workout.muscle_${templateExercise.targetMuscle}'.tr()
            : '',
      );

      // Если нашли совпадение по имени в прошлой тренировке — копируем
      // все её подходы (вес и повторы), но делаем их невыполненными,
      // чтобы пользователь заново отмечал прогресс сегодняшней тренировки.
      if (matchingOld != null && matchingOld.sets.isNotEmpty) {
        // Заново загружаем тренировку, чтобы получить ID только что
        // добавленного упражнения (addExercise не возвращает сам объект).
        final updatedWorkout = await _workoutService.getWorkout(workout.id);
        final newExercise = updatedWorkout!.exercises.last;

        for (final oldSet in matchingOld.sets) {
          await _workoutService.addSet(
            workout.id,
            newExercise.id,
            reps: oldSet.reps,
            weight: oldSet.weight,
          );
        }
      }
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => WorkoutEditorPage(workoutId: workout.id)),
      );
    }
  }
}
