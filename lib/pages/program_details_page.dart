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

import 'package:uuid/uuid.dart';
import '../models/exercise_template.dart';
import 'exercise_picker_page.dart';

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
          // Кнопка меню действий — только для своих программ.
          // Для готовых программ от нас (isCustom == false) её не будет,
          // как и планировали заранее.
          if (_program!.isCustom)
            GestureDetector(
              onTap: _showProgramActionsMenu,
              child: const Icon(Icons.more_vert, color: Colors.white, size: 22),
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

  // Показать нижнее меню с действиями над программой: редактировать / удалить.
  Future<void> _showProgramActionsMenu() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFFF97316)),
              title: Text('programs.edit_program'.tr(),
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showEditProgramMetaDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add, color: Color(0xFFF97316)),
              title: Text('programs.add_workout_day'.tr(),
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showAddWorkoutDayToSavedProgram();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('programs.delete_program'.tr(),
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteProgramDialog();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Диалог редактирования названия и расписания программы.
  Future<void> _showEditProgramMetaDialog() async {
    final nameController = TextEditingController(text: _program!.name);
    final scheduleController = TextEditingController(text: _program!.schedule);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF97316), width: 1),
        ),
        title: Text(
          'programs.edit_program'.tr(),
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                hintText: 'programs.program_name_hint'.tr(),
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: scheduleController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                hintText: 'programs.schedule_hint'.tr(),
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('workout.cancel'.tr(),
                style: const TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('programs.name_required'.tr()),
                      backgroundColor: Colors.red),
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

    if (result == true) {
      await _programService.updateProgramMeta(
        widget.programId,
        name: nameController.text.trim(),
        schedule: scheduleController.text.trim(),
      );
      await _loadProgram();
    }
  }

  // Диалог подтверждения удаления программы целиком.
  Future<void> _showDeleteProgramDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.red, width: 1),
        ),
        title: Text(
          'programs.delete_confirm'.tr(),
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'programs.delete_message'.tr(),
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('workout.cancel'.tr(),
                style: const TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );

    if (result == true) {
      await _programService.deleteProgram(widget.programId);
      // После удаления возвращаемся на список программ —
      // на этом экране больше нечего показывать.
      if (mounted) Navigator.pop(context);
    }
  }

  // Показать диалог добавления нового дня в уже сохранённую программу.
  // По структуре похож на диалог в create_program_page.dart, но здесь
  // результат сразу сохраняется через ProgramService, а не держится
  // в памяти до общего сохранения.
  Future<void> _showAddWorkoutDayToSavedProgram(
      {ProgramWorkout? existingWorkout}) async {
    final dayNameController =
        TextEditingController(text: existingWorkout?.name ?? '');
    final List<ProgramExercise> dayExercises =
        existingWorkout != null ? List.from(existingWorkout.exercises) : [];

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFF97316), width: 1),
          ),
          title: Text(
            'programs.new_workout_day'.tr(),
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: dayNameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      hintText: 'programs.day_name_hint'.tr(),
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'programs.exercises'.tr(),
                    style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  ...dayExercises.map((ex) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(ex.name,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13))),
                          Text(
                            '${ex.targetSets} ${'programs.sets_short'.tr()}',
                            style: const TextStyle(
                                color: Color(0xFFF97316),
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                setDialogState(() => dayExercises.remove(ex)),
                            child: const Icon(Icons.close,
                                color: Colors.red, size: 16),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final template = await Navigator.push<ExerciseTemplate>(
                        dialogContext,
                        MaterialPageRoute(
                            builder: (context) => const ExercisePickerPage()),
                      );
                      if (template != null) {
                        final lang = dialogContext.locale.languageCode;
                        setDialogState(() {
                          dayExercises.add(ProgramExercise(
                            name: template.getName(lang),
                            targetMuscle: template.muscleGroup,
                            targetSets: 3,
                          ));
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFF97316).withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add,
                              color: Color(0xFFF97316), size: 16),
                          const SizedBox(width: 4),
                          Text('workout.add_exercise'.tr(),
                              style: const TextStyle(
                                  color: Color(0xFFF97316),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('workout.cancel'.tr(),
                  style: const TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                if (dayNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                        content: Text('programs.day_name_required'.tr()),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text('workout.save'.tr()),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      if (existingWorkout != null) {
        // Редактирование существующего дня — сначала удаляем старую версию,
        // затем добавляем обновлённую. ProgramService не имеет отдельного
        // метода "обновить день", поэтому используем комбинацию удалить+добавить,
        // сохраняя тот же id чтобы связь с историей (programWorkoutName)
        // осталась корректной, если имя дня не поменяли.
        await _programService.removeWorkoutFromProgram(
            widget.programId, existingWorkout.id);
        await _programService.addWorkoutToProgram(
          widget.programId,
          ProgramWorkout(
            id: existingWorkout.id,
            name: dayNameController.text.trim(),
            exercises: dayExercises,
          ),
        );
      } else {
        // Новый день — просто добавляем с новым сгенерированным id.
        await _programService.addWorkoutToProgram(
          widget.programId,
          ProgramWorkout(
            id: const Uuid().v4(),
            name: dayNameController.text.trim(),
            exercises: dayExercises,
          ),
        );
      }
      await _loadProgram();
    }
  }

  // Диалог подтверждения удаления одного дня из программы.
  Future<void> _showDeleteWorkoutDayDialog(ProgramWorkout workout) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.red, width: 1),
        ),
        title: Text(
          'programs.delete_day_confirm'.tr(),
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          workout.name,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('workout.cancel'.tr(),
                style: const TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );

    if (result == true) {
      await _programService.removeWorkoutFromProgram(
          widget.programId, workout.id);
      await _loadProgram();
    }
  }

  // Карточка одного тренировочного дня с кнопкой "Начать"/"Повторить".
  Widget _buildWorkoutCard(ProgramWorkout workout) {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  workout.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
              // Кнопки редактирования/удаления дня — только для своих программ.
              if (_program!.isCustom) ...[
                GestureDetector(
                  onTap: () => _showAddWorkoutDayToSavedProgram(
                      existingWorkout: workout),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.edit, color: Color(0xFFF97316), size: 16),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showDeleteWorkoutDayDialog(workout),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child:
                        Icon(Icons.delete_outline, color: Colors.red, size: 16),
                  ),
                ),
              ],
            ],
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
      ).then((_) => _loadProgram());
      // .then() гарантированно сработает когда мы вернёмся с экрана
      // редактора тренировки — надёжнее чем полагаться на didChangeDependencies,
      // которое не всегда переигрывается при обычном Navigator.pop().
    }
  }

  // Повторить тренировку: берём АКТУАЛЬНЫЙ список упражнений из шаблона программы

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
      ).then((_) => _loadProgram());
    }
  }
}
