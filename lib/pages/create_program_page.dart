// Подключаем базовые виджеты Flutter.
import 'package:flutter/material.dart';

// Подключаем easy_localization для переводов.
import 'package:easy_localization/easy_localization.dart';

// Подключаем модели программы.
import '../models/program_models.dart';

// Подключаем сервис для сохранения программы.
import '../services/program_service.dart';

// Подключаем библиотеку для генерации уникальных ID —
// нужна нам здесь потому что мы создаём ProgramWorkout прямо на этом экране,
// до того как он будет сохранён через сервис.
import 'package:uuid/uuid.dart';
// Подключаем модель шаблона упражнения, чтобы показывать его в списке.
import '../models/exercise_template.dart';
// Подключаем экран выбора упражнения, чтобы открывать его при добавлении нового упражнения в день.
import 'exercise_picker_page.dart';

class CreateProgramPage extends StatefulWidget {
  const CreateProgramPage({super.key});

  @override
  State<CreateProgramPage> createState() => _CreateProgramPageState();
}

class _CreateProgramPageState extends State<CreateProgramPage> {
  final _service = ProgramService();
  final _uuid = const Uuid();

  // Контроллеры для текстовых полей названия и расписания программы.
  final _nameController = TextEditingController();
  final _scheduleController = TextEditingController();

  // Список дней/тренировок которые пользователь добавляет в программу.
  // Мы держим их локально в памяти экрана, пока пользователь не нажмёт "Сохранить" —
  // только тогда всё целиком уйдёт в сервис и сохранится на диск.
  final List<ProgramWorkout> _workouts = [];

  @override
  void dispose() {
    // Освобождаем контроллеры когда экран закрывается — хорошая практика,
    // предотвращает утечки памяти.
    _nameController.dispose();
    _scheduleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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

  // Шапка с кнопкой назад и заголовком.
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
          Text(
            'programs.create_program'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Поле ввода названия программы.
  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'programs.program_name'.tr(),
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            hintText: 'programs.program_name_hint'.tr(),
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
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

  // Поле ввода расписания (текстовое, свободный формат).
  Widget _buildScheduleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'programs.schedule'.tr(),
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _scheduleController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            hintText: 'programs.schedule_hint'.tr(),
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
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

  // Секция со списком добавленных дней/тренировок + кнопка добавить ещё.
  Widget _buildWorkoutsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'programs.workouts_in_program'.tr(),
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 8),

        // Показываем каждый добавленный день как карточку.
        // Пока это просто заглушка-список — редактирование содержимого дня добавим следующим шагом.
        ..._workouts.map((w) => _buildWorkoutCard(w)).toList(),

        const SizedBox(height: 8),

        // Кнопка добавления нового дня — пока заглушка.
        GestureDetector(
          onTap: _showAddWorkoutDayDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: Color(0xFFF97316), size: 18),
                const SizedBox(width: 6),
                Text(
                  'programs.add_workout_day'.tr(),
                  style: const TextStyle(
                    color: Color(0xFFF97316),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
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
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ),
          // Кнопка удаления этого дня из списка.
          GestureDetector(
            onTap: () {
              setState(() {
                _workouts.remove(workout);
              });
            },
            child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          ),
        ],
      ),
    );
  }

  // Кнопка сохранения программы внизу экрана.
  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saveProgram,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
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

  // Сохранить программу через сервис.
  Future<void> _saveProgram() async {
    final name = _nameController.text.trim();

    // Простая проверка — название обязательно.
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('programs.name_required'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Создаём программу через сервис (это сразу сохранит её с пустым списком тренировок).
    final program = await _service.createProgram(
      name: name,
      schedule: _scheduleController.text.trim(),
    );

    // Добавляем в неё все тренировочные дни которые пользователь успел создать локально.
    for (final workout in _workouts) {
      await _service.addWorkoutToProgram(program.id, workout);
    }

    // Закрываем экран и возвращаемся на список программ.
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // Открыть диалог для создания нового тренировочного дня.
Future<void> _showAddWorkoutDayDialog() async {
  // Локальный контроллер для названия дня — например "День 1: Грудь".
  final dayNameController = TextEditingController();

  // Временный список упражнений для этого дня, пока пользователь их добавляет.
  // StatefulBuilder ниже позволяет обновлять этот список внутри диалога
  // без пересборки всего экрана позади диалога.
  final List<ProgramExercise> dayExercises = [];

  final result = await showDialog<bool>(
    context: context,
    // barrierDismissible: false — чтобы случайное нажатие мимо не закрыло
    // диалог и не потерялись добавленные упражнения.
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
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Поле названия дня.
                TextField(
                  controller: dayNameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    hintText: 'programs.day_name_hint'.tr(),
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
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
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, letterSpacing: 1),
                ),
                const SizedBox(height: 8),

                // Список уже добавленных упражнений в этот день.
                ...dayExercises.map((ex) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
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
                        // Показываем сколько подходов запланировано для этого упражнения.
                        Text(
                          '${ex.targetSets} ${'programs.sets_short'.tr()}',
                          style: const TextStyle(color: Color(0xFFF97316), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            // setDialogState обновляет только этот диалог,
                            // а не весь экран позади него.
                            setDialogState(() {
                              dayExercises.remove(ex);
                            });
                          },
                          child: const Icon(Icons.close, color: Colors.red, size: 16),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                const SizedBox(height: 8),

                // Кнопка открытия библиотеки упражнений.
                GestureDetector(
                  onTap: () async {
                    // Открываем уже готовую страницу выбора упражнения.
                    final template = await Navigator.push<ExerciseTemplate>(
                      dialogContext,
                      MaterialPageRoute(builder: (context) => const ExercisePickerPage()),
                    );

                    // Если пользователь что-то выбрал — добавляем в список этого дня.
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
                      border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, color: Color(0xFFF97316), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'workout.add_exercise'.tr(),
                          style: const TextStyle(color: Color(0xFFF97316), fontSize: 12, fontWeight: FontWeight.bold),
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
            child: Text('workout.cancel'.tr(), style: const TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              if (dayNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('programs.day_name_required'.tr()),
                    backgroundColor: Colors.red,
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

  // Если пользователь нажал "Сохранить" — создаём объект дня и добавляем
  // его в общий список тренировок программы на основном экране.
  if (result == true) {
    setState(() {
      _workouts.add(ProgramWorkout(
        id: _uuid.v4(),
        name: dayNameController.text.trim(),
        exercises: dayExercises,
      ));
    });
  }
}
}