// Подключаем базовые виджеты Flutter.
import 'package:flutter/material.dart';

// Подключаем easy_localization для переводов.
import 'package:easy_localization/easy_localization.dart';

// Подключаем модель программы.
import '../models/program_models.dart';

// Подключаем сервис программ — чтобы заново загрузить программу по ID
// (на случай если что-то изменилось, например через другой экран).
import '../services/program_service.dart';
import '../services/exercise_catalog_service.dart';
import '../services/exercise_library_service.dart';

// Подключаем сервис тренировок — он нам нужен чтобы создать
// настоящую Workout на основе шаблона ProgramWorkout.
import '../services/workout_service.dart';

// Подключаем редактор тренировки — на него мы перейдём после того как
// создадим Workout из шаблона программы.
import 'workout_editor_page.dart';
// Подключаем модели тренировок, чтобы создать Workout и Exercise.
import '../models/workout_models.dart';

import 'package:uuid/uuid.dart';
import 'exercise_picker_page.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/exercise_display.dart';
import '../widgets/exercise_info_button.dart';
import '../widgets/weekday_selector.dart';
import '../widgets/exercise_plan_editor.dart';

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
  // Map: ID дня программы → последняя тренировка этого дня (если была).
  // Загружаем один раз при открытии экрана, чтобы для каждой карточки
  // дня сразу знать показывать "Начать" или "Повторить", не делая
  // отдельный запрос на каждую карточку при построении списка.
  Map<String, Workout> _lastWorkoutsByDay = {};
  // ID дней программы, карточки которых сейчас раскрыты (список упражнений).
  // Изначально все свёрнуты; раскрытыми могут быть несколько одновременно.
  final Set<String> _expandedDayIds = {};
  // Описание программы раскрыто полностью (иначе — первые 2 строки).
  bool _descriptionExpanded = false;

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

    // Для каждого дня программы ищем — была ли уже тренировка этого дня
    // внутри этой же программы (по ID дня, у старых тренировок — по названию).
    // Складываем результаты в Map для быстрого доступа при отрисовке карточек.
    final Map<String, Workout> lastWorkouts = {};
    if (program != null) {
      for (final workout in program.workouts) {
        final last = await _workoutService.getLastWorkoutForProgramDay(
          program.id,
          dayId: workout.id,
          dayName: workout.name,
        );
        // Добавляем в Map только если действительно нашли прошлую тренировку —
        // иначе для этого дня в Map не будет записи, и мы будем знать
        // что нужно показать "Начать", а не "Повторить".
        if (last != null) {
          lastWorkouts[workout.id] = last;
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent))
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
                              _buildDescription(),
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
    return PageHeader(
      title: _program!.name,
      // Кнопка меню действий — только для своих программ.
      // Для готовых программ от нас (isCustom == false) её не будет,
      // как и планировали заранее.
      trailing: _program!.isCustom
          ? IconButton(
              onPressed: _showProgramActionsMenu,
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
            )
          : null,
    );
  }

  // Дни недели программы: «Пн · Ср · Пт», все 7 — «Каждый день», не выбраны — ничего.
  Widget _buildScheduleInfo() {
    final days = formatScheduleDays(_program!.scheduleDays);
    if (days.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: AppColors.accent, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              days,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Описание программы: свёрнуто до 2 строк, «Показать ещё / Свернуть»
  // появляется, только если текст в 2 строки не помещается.
  Widget _buildDescription() {
    final text = _program!.description.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    const style = TextStyle(color: AppColors.textSoft, fontSize: 13, height: 1.35);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Меряем, длиннее ли текст двух строк
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 2,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: style,
              maxLines: _descriptionExpanded ? null : 2,
              overflow: _descriptionExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            if (overflows)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(
                    () => _descriptionExpanded = !_descriptionExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    _descriptionExpanded
                        ? 'programs.show_less'.tr()
                        : 'programs.show_more'.tr(),
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Заголовок секции со списком тренировок.
  Widget _buildWorkoutsHeader() {
    return Text(
      '${'programs.workouts_in_program'.tr()} (${_program!.workouts.length})',
      style: const TextStyle(
          color: AppColors.textMuted, fontSize: 11, letterSpacing: 1),
    );
  }

  // Показать нижнее меню с действиями над программой: редактировать / удалить.
  Future<void> _showProgramActionsMenu() async {
    showAppBottomSheet(
      context: context,
      builder: (context) => [
        AppSheetHeader(
          leading:
              const Icon(Icons.assignment, color: AppColors.accent, size: 20),
          title: _program!.name,
        ),
        ListTile(
          leading: const Icon(Icons.edit, color: AppColors.accent),
          title: Text('programs.edit_program'.tr(),
              style: const TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(context);
            _showEditProgramMetaDialog();
          },
        ),
        ListTile(
          leading: const Icon(Icons.add, color: AppColors.accent),
          title: Text('programs.add_workout_day'.tr(),
              style: const TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(context);
            _showAddWorkoutDayToSavedProgram();
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete, color: AppColors.danger),
          title: Text('programs.delete_program'.tr(),
              style: const TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(context);
            _showDeleteProgramDialog();
          },
        ),
      ],
    );
  }

  // Диалог редактирования названия, дней недели и описания программы.
  Future<void> _showEditProgramMetaDialog() async {
    final nameController = TextEditingController(text: _program!.name);
    final descriptionController =
        TextEditingController(text: _program!.description);
    List<int> scheduleDays = List.of(_program!.scheduleDays);

    // Ошибку пустого названия показываем прямо под полем
    String? nameError;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          title: 'programs.edit_program'.tr(),
          // Фиксированная ширина нужна WeekdaySelector (LayoutBuilder внутри AlertDialog)
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  // Начали печатать — убираем ошибку
                  onChanged: (_) {
                    if (nameError != null) {
                      setDialogState(() => nameError = null);
                    }
                  },
                  decoration: appDialogInputDecoration(
                    labelText: 'programs.program_name_label'.tr(),
                    hintText: 'programs.program_name_hint'.tr(),
                    errorText: nameError,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'programs.schedule_label'.tr(),
                  style: const TextStyle(color: AppColors.accent, fontSize: 12),
                ),
                const SizedBox(height: 6),
                WeekdaySelector(
                  selectedDays: scheduleDays,
                  onChanged: (days) => setDialogState(() => scheduleDays = days),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: appDialogInputDecoration(
                    labelText: 'programs.description_label'.tr(),
                    hintText: 'programs.description_hint'.tr(),
                  ),
                ),
              ],
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
                if (nameController.text.trim().isEmpty) {
                  setDialogState(
                      () => nameError = 'programs.name_required'.tr());
                  return;
                }
                Navigator.pop(context, true);
              },
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _programService.updateProgramMeta(
        widget.programId,
        name: nameController.text.trim(),
        description: descriptionController.text.trim(),
        scheduleDays: scheduleDays,
      );
      await _loadProgram();
    }
  }

  // Диалог подтверждения удаления программы целиком.
  Future<void> _showDeleteProgramDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: 'programs.delete_confirm'.tr(),
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.danger,
        borderColor: AppColors.danger,
        content: Text(
          'programs.delete_message'.tr(),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          AppDialogCancelButton(
            label: 'workout.cancel'.tr(),
            onPressed: () => Navigator.pop(context, false),
          ),
          AppDialogConfirmButton(
            label: 'workout.delete'.tr(),
            color: AppColors.danger,
            onPressed: () => Navigator.pop(context, true),
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
    // Копии упражнений: план повторов меняется прямо в них, и при «Отмене»
    // сохранённый день остаётся нетронутым
    final List<ProgramExercise> dayExercises = existingWorkout != null
        ? existingWorkout.exercises.map((e) => e.copy()).toList()
        : [];

    // Ошибку пустого названия дня показываем прямо под полем
    String? nameError;
    // «Такое упражнение уже есть в библиотеке» — тоже в самом диалоге:
    // SnackBar оказался бы за его фоном
    String? libraryNote;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AppDialog(
          // Для уже существующего дня — «Редактировать», для нового — «Новый»
          title: existingWorkout != null
              ? 'programs.edit_workout_day'.tr()
              : 'programs.new_workout_day'.tr(),
          // Узкие поля по бокам — больше места для «повторы от — до»
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: dayNameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  // Начали печатать — убираем ошибку
                  onChanged: (_) {
                    if (nameError != null) {
                      setDialogState(() => nameError = null);
                    }
                  },
                  decoration: appDialogInputDecoration(
                    labelText: 'programs.day_name_label'.tr(),
                    hintText: 'programs.day_name_hint'.tr(),
                    errorText: nameError,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'programs.exercises'.tr(),
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                ...dayExercises.map((ex) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
                    decoration: BoxDecoration(
                        color: AppColors.surfaceInset,
                        borderRadius: BorderRadius.circular(8)),
                    // Первая строка — название, ниже — подходы и «повторы от — до»
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(
                                    programExerciseDisplayName(context, ex),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13))),
                            ExerciseInfoButton(templateId: ex.templateId, name: ex.name),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setDialogState(
                                  () => dayExercises.remove(ex)),
                              child: const Icon(Icons.close,
                                  color: AppColors.danger, size: 16),
                            ),
                          ],
                        ),
                        ExercisePlanEditor(key: ObjectKey(ex), exercise: ex),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),
                if (libraryNote != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.textMuted, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(libraryNote!,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                GestureDetector(
                  onTap: () async {
                    final picked = await Navigator.push<PickedExercise>(
                      dialogContext,
                      MaterialPageRoute(
                          builder: (context) => const ExercisePickerPage()),
                    );
                    if (picked != null) {
                      final template = picked.template;
                      final lang = dialogContext.locale.languageCode;
                      setDialogState(() {
                        libraryNote = picked.alreadyInLibrary
                            ? alreadyInLibraryText(dialogContext, template)
                            : null;
                        dayExercises.add(ProgramExercise(
                          name: template.getName(lang),
                          targetMuscle: template.muscleGroup,
                          templateId: template.id,
                          targetSets: 3,
                        ));
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add,
                            color: AppColors.accent, size: 16),
                        const SizedBox(width: 4),
                        Text('workout.add_exercise'.tr(),
                            style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            AppDialogCancelButton(
              label: 'workout.cancel'.tr(),
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            AppDialogConfirmButton(
              label: 'workout.save'.tr(),
              onPressed: () {
                if (dayNameController.text.trim().isEmpty) {
                  setDialogState(
                      () => nameError = 'programs.day_name_required'.tr());
                  return;
                }
                // Одно заполненное поле — для обоих, «от» не больше «до»
                for (final ex in dayExercises) {
                  ex.normalizeRepsRange();
                }
                Navigator.pop(dialogContext, true);
              },
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      if (existingWorkout != null) {
        // Редактирование существующего дня — заменяем его на том же месте
        // (порядок дней важен) и с тем же id. История и «Повторить» ищут
        // тренировки дня по ID дня. Старые тренировки (без ID дня, найденные
        // по старому названию) сначала привязываем к ID — тогда переименование
        // дня не теряет их историю.
        await _workoutService.linkOldWorkoutsToProgramDay(
          widget.programId,
          dayId: existingWorkout.id,
          dayName: existingWorkout.name,
        );
        await _programService.updateWorkoutInProgram(
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
      builder: (context) => AppDialog(
        title: 'programs.delete_day_confirm'.tr(),
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.danger,
        borderColor: AppColors.danger,
        content: Text(
          workout.name,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          AppDialogCancelButton(
            label: 'workout.cancel'.tr(),
            onPressed: () => Navigator.pop(context, false),
          ),
          AppDialogConfirmButton(
            label: 'workout.delete'.tr(),
            color: AppColors.danger,
            onPressed: () => Navigator.pop(context, true),
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
    final lastWorkout = _lastWorkoutsByDay[workout.id];
    final hasHistory = lastWorkout != null;
    final hasExercises = workout.exercises.isNotEmpty;
    final isExpanded = _expandedDayIds.contains(workout.id);

    // Нажатие на карточку раскрывает/сворачивает список упражнений дня.
    // Кнопки внутри (редактировать, удалить, начать) срабатывают сами по себе
    // и карточку не переключают.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasExercises
          ? () => setState(() {
                if (isExpanded) {
                  _expandedDayIds.remove(workout.id);
                } else {
                  _expandedDayIds.add(workout.id);
                }
              })
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withOpacity(0.2)),
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
                      child: Icon(Icons.edit, color: AppColors.accent, size: 16),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showDeleteWorkoutDayDialog(workout),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child:
                          Icon(Icons.delete_outline, color: AppColors.danger, size: 16),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${workout.exercises.length} ${'programs.exercises_count'.tr()}',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                // Стрелка поворачивается, показывая раскрыта ли карточка
                if (hasExercises) ...[
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more,
                        color: AppColors.textMuted, size: 16),
                  ),
                ],
              ],
            ),

            // Список упражнений дня — только для просмотра
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: workout.exercises
                            .map((ex) => _buildDayExerciseRow(ex))
                            .toList(),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),

            // Показываем дату последнего выполнения, только если она есть.
            if (hasHistory) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.history, color: AppColors.program, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${'programs.last_done'.tr()}: ${_formatLastDate(lastWorkout.finishedAt)}',
                    style:
                        const TextStyle(color: AppColors.program, fontSize: 11),
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
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Одна строка упражнения в раскрытой карточке дня: название, мышца, подходы.
  Widget _buildDayExerciseRow(ProgramExercise ex) {
    // В шаблоне хранится ключ мышцы (chest) — показываем перевод
    final muscle = programExerciseMuscleLabel(context, ex);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  programExerciseDisplayName(context, ex),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                if (muscle.isNotEmpty)
                  Text(
                    muscle,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          // Демо упражнения; нажатие не сворачивает карточку дня
          ExerciseInfoButton(templateId: ex.templateId, name: ex.name),
          const SizedBox(width: 8),
          // С планом повторов — «4 × 8–12» (или «3 × 10»), без него — «4 подх.»
          Text(
            ex.repsRangeText != null
                ? '${ex.targetSets} × ${ex.repsRangeText}'
                : '${ex.targetSets} ${'programs.sets_short'.tr()}',
            style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.bold),
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

  // id шаблона упражнения программы (если вдруг нет — ищем по названию)
  String? _templateIdOf(ProgramExercise exercise) =>
      exercise.templateId ?? ExerciseCatalogService().idForName(exercise.name);

  // Ключ группы мышц для тренировки: из программы, иначе из шаблона
  String? _muscleGroupOf(ProgramExercise exercise) {
    if (ExerciseLibraryService.validGroups.contains(exercise.targetMuscle)) {
      return exercise.targetMuscle;
    }
    final group = ExerciseCatalogService()
            .templateById(_templateIdOf(exercise))
            ?.muscleGroup ??
        '';
    return group.isEmpty ? null : group;
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
      programWorkoutId: template.id, // Связь с днём по ID — переживает переименование дня
      programName: _program!.name, // Сохраняем "снимок" названия программы
    );

    // Добавляем каждое упражнение из шаблона, пока без подходов.
    // План (подходы, повторы) копируем «снимком» — это цель на карточке упражнения.
    for (final exercise in template.exercises) {
      await _workoutService.addExercise(
        workout.id,
        name: exercise.name,
        targetMuscle: exercise.targetMuscle.isNotEmpty
            ? 'workout.muscle_${exercise.targetMuscle}'.tr()
            : '',
        templateId: _templateIdOf(exercise),
        muscleGroup: _muscleGroupOf(exercise),
        plannedSets: exercise.targetSets,
        plannedRepsMin: exercise.repsMin,
        plannedRepsMax: exercise.repsMax,
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
  // (а не из старой тренировки), но для каждого упражнения — если это то же
  // упражнение, что в прошлой тренировке (по identityKey: id шаблона, иначе
  // название на любом языке) — подтягиваем оттуда подходы (вес и повторы),
  // чтобы не вводить всё заново руками.
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
      programWorkoutId: template.id, // Связь с днём по ID — переживает переименование дня
      programName: _program!.name, // Сохраняем "снимок" названия программы
      // Сохраняем связь с прошлой тренировкой — это то же поле что
      // используется в обычном copyWorkout(), нужно для сравнения
      // "было / стало" на экране редактора (стрелочки прогресса).
      copiedFromWorkoutId: lastWorkout.id,
    );

    // Идём по упражнениям из АКТУАЛЬНОГО шаблона программы, а не из старой тренировки.
    // Это значит: если упражнение убрали из шаблона — оно не попадёт сюда.
    // Если добавили новое — оно попадёт, просто без истории весов.
    final catalog = ExerciseCatalogService();
    for (final templateExercise in template.exercises) {
      // Ищем в прошлой тренировке то же упражнение — по id шаблона, а не по
      // тексту названия: день мог быть собран на другом языке.
      final key = catalog.identityKey(
          templateId: templateExercise.templateId, name: templateExercise.name);
      Exercise? matchingOld;
      try {
        matchingOld = lastWorkout.exercises.firstWhere(
          (e) => catalog.identityKey(templateId: e.templateId, name: e.name) == key,
        );
      } catch (e) {
        // Совпадения нет — это новое упражнение в шаблоне, добавим его пустым.
        matchingOld = null;
      }

      // Добавляем упражнение в новую тренировку вместе с планом из шаблона
      // (цель на карточке; подходы не создаём — они подтягиваются ниже, как раньше).
      await _workoutService.addExercise(
        workout.id,
        name: templateExercise.name,
        targetMuscle: templateExercise.targetMuscle.isNotEmpty
            ? 'workout.muscle_${templateExercise.targetMuscle}'.tr()
            : '',
        templateId: _templateIdOf(templateExercise),
        muscleGroup: _muscleGroupOf(templateExercise),
        plannedSets: templateExercise.targetSets,
        plannedRepsMin: templateExercise.repsMin,
        plannedRepsMax: templateExercise.repsMax,
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
