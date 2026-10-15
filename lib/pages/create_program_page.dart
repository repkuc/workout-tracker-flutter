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
import '../models/exercise_template.dart';

// Подключаем экран выбора упражнения.
import 'exercise_picker_page.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';

class CreateProgramPage extends StatefulWidget {
  const CreateProgramPage({super.key});

  @override
  State<CreateProgramPage> createState() => _CreateProgramPageState();
}

class _CreateProgramPageState extends State<CreateProgramPage> {
  final _service = ProgramService();
  final _uuid = const Uuid();

  final _nameController = TextEditingController();
  final _scheduleController = TextEditingController();

  final List<ProgramWorkout> _workouts = [];

  @override
  void dispose() {
    _nameController.dispose();
    _scheduleController.dispose();
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
            fillColor: AppColors.inputFill,
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

  Widget _buildScheduleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'programs.schedule'.tr(),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _scheduleController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.inputFill,
            hintText: 'programs.schedule_hint'.tr(),
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
      schedule: _scheduleController.text.trim(),
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.dialogBorder, width: 1),
        ),
        title: Text(
          workout.name,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
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
                          ex.name,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      Text(
                        '${ex.targetSets} ${'programs.sets_short'.tr()}',
                        style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('workout.close'.tr(), style: const TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  // Открыть диалог для создания нового дня, либо для редактирования уже существующего.
  Future<void> _showAddWorkoutDayDialog({ProgramWorkout? existingWorkout, int? existingIndex}) async {
    final dayNameController = TextEditingController(text: existingWorkout?.name ?? '');

    final List<ProgramExercise> dayExercises = existingWorkout != null
        ? List.from(existingWorkout.exercises)
        : [];

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.dialogBorder, width: 1),
          ),
          title: Text(
            'programs.new_workout_day'.tr(),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                      fillColor: AppColors.inputFill,
                      hintText: 'programs.day_name_hint'.tr(),
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceInset,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ex.name,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                          Text(
                            '${ex.targetSets} ${'programs.sets_short'.tr()}',
                            style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
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
                    );
                  }).toList(),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final template = await Navigator.push<ExerciseTemplate>(
                        dialogContext,
                        MaterialPageRoute(builder: (context) => const ExercisePickerPage()),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('workout.cancel'.tr(), style: const TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                if (dayNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('programs.day_name_required'.tr()),
                      backgroundColor: AppColors.danger,
                    ),
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