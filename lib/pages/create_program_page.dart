// Подключаем базовые виджеты Flutter.
import 'package:flutter/material.dart';

// Подключаем easy_localization для переводов.
import 'package:easy_localization/easy_localization.dart';

// Подключаем модели программы.
import '../models/program_models.dart';

// Подключаем сервис для сохранения программы.
import '../services/program_service.dart';

// Подключаем библиотеку для генерации уникальных ID.
import 'package:uuid/uuid.dart';

// Подключаем модель шаблона упражнения.

// Подключаем экран выбора упражнения.
import 'exercise_picker_page.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import '../widgets/app_dialog.dart';
import '../widgets/exercise_display.dart';
import '../widgets/exercise_info_button.dart';
import '../widgets/weekday_selector.dart';
import '../widgets/exercise_plan_editor.dart';

class CreateProgramPage extends StatefulWidget {
  const CreateProgramPage({super.key});

  @override
  State<CreateProgramPage> createState() => _CreateProgramPageState();
}

class _CreateProgramPageState extends State<CreateProgramPage> {
  final _service = ProgramService();
  final _uuid = const Uuid();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Выбранные дни недели (1 = Пн … 7 = Вс)
  List<int> _scheduleDays = [];

  final List<ProgramWorkout> _workouts = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNameField(),
                    const SizedBox(height: 16),
                    _buildScheduleField(),
                    const SizedBox(height: 16),
                    _buildDescriptionField(),
                    const SizedBox(height: 20),
                    _buildWorkoutsSection(),
                  ],
                ),
              ),
            ),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return PageHeader(title: 'programs.create_program'.tr());
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'programs.program_name'.tr(),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.inputFillOnPage,
            hintText: 'programs.program_name_hint'.tr(),
            hintStyle: const TextStyle(color: AppColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // Дни недели — 7 переключателей Пн … Вс
  Widget _buildScheduleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'programs.schedule'.tr(),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        WeekdaySelector(
          selectedDays: _scheduleDays,
          unselectedColor: AppColors.inputFillOnPage,
          onChanged: (days) => setState(() => _scheduleDays = days),
        ),
      ],
    );
  }

  // Описание программы — многострочное (рекомендации, как подбирать вес и т.п.)
  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'programs.description'.tr(),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          minLines: 2,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.inputFillOnPage,
            hintText: 'programs.description_hint'.tr(),
            hintStyle: const TextStyle(color: AppColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'programs.workouts_in_program'.tr(),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        ..._workouts.map((w) => _buildWorkoutCard(w)).toList(),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showAddWorkoutDayDialog(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: AppColors.accent, size: 18),
                const SizedBox(width: 6),
                Text(
                  'programs.add_workout_day'.tr(),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Одна карточка тренировочного дня в списке.
  Widget _buildWorkoutCard(ProgramWorkout workout) {
    final index = _workouts.indexOf(workout);

    return GestureDetector(
      onTap: () => _showViewWorkoutDayDialog(workout),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.name,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${workout.exercises.length} ${'programs.exercises_count'.tr()}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showAddWorkoutDayDialog(existingWorkout: workout, existingIndex: index),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.edit, color: AppColors.accent, size: 18),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _workouts.remove(workout);
                });
              },
              child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saveProgram,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            'workout.save'.tr(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProgram() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('programs.name_required'.tr()),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final program = await _service.createProgram(
      name: name,
      description: _descriptionController.text.trim(),
      scheduleDays: _scheduleDays,
    );

    for (final workout in _workouts) {
      await _service.addWorkoutToProgram(program.id, workout);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  // Показать день только для просмотра — без возможности что-то менять.
  Future<void> _showViewWorkoutDayDialog(ProgramWorkout workout) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: workout.name,
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: workout.exercises.map((ex) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceInset,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        programExerciseDisplayName(context, ex),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    ExerciseInfoButton(templateId: ex.templateId, name: ex.name),
                    // С планом повторов — «4 × 8–12», без него — «4 подх.»
                    Text(
                      ex.repsRangeText != null
                          ? '${ex.targetSets} × ${ex.repsRangeText}'
                          : '${ex.targetSets} ${'programs.sets_short'.tr()}',
                      style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          AppDialogCancelButton(
            label: 'workout.close'.tr(),
            color: AppColors.accent,
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  // Открыть диалог для создания нового дня, либо для редактирования уже существующего.
  Future<void> _showAddWorkoutDayDialog({ProgramWorkout? existingWorkout, int? existingIndex}) async {
    final dayNameController = TextEditingController(text: existingWorkout?.name ?? '');

    // Копии упражнений: план повторов меняется прямо в них, и при «Отмене»
    // исходный день остаётся нетронутым
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                ...dayExercises.map((ex) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceInset,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    // Первая строка — название, ниже — подходы и «повторы от — до»
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                programExerciseDisplayName(context, ex),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                            ExerciseInfoButton(templateId: ex.templateId, name: ex.name),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  dayExercises.remove(ex);
                                });
                              },
                              child: const Icon(Icons.close, color: AppColors.danger, size: 16),
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
                      MaterialPageRoute(builder: (context) => const ExercisePickerPage()),
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
                      border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, color: AppColors.accent, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'workout.add_exercise'.tr(),
                          style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
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
      setState(() {
        if (existingIndex != null) {
          _workouts[existingIndex] = ProgramWorkout(
            id: existingWorkout!.id,
            name: dayNameController.text.trim(),
            exercises: dayExercises,
          );
        } else {
          _workouts.add(ProgramWorkout(
            id: _uuid.v4(),
            name: dayNameController.text.trim(),
            exercises: dayExercises,
          ));
        }
      });
    }
  }
}