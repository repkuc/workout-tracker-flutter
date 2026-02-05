import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/workout_service.dart';
import '../models/workout_models.dart';

class WorkoutEditorPage extends StatefulWidget {
  final String workoutId;

  const WorkoutEditorPage({
    super.key,
    required this.workoutId,
  });

  @override
  State<WorkoutEditorPage> createState() => _WorkoutEditorPageState();
}

class _WorkoutEditorPageState extends State<WorkoutEditorPage> {
  final _service = WorkoutService();
  Workout? _workout;
  bool _isLoading = true;

  // Контроллеры для формы добавления упражнения
  final _exerciseNameController = TextEditingController();
  final _targetMuscleController = TextEditingController();

  // Контроллеры для формы добавления подхода
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWorkout();
  }

  @override
  void dispose() {
    _exerciseNameController.dispose();
    _targetMuscleController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkout() async {
    final workout = await _service.getWorkout(widget.workoutId);
    setState(() {
      _workout = workout;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Градиентный фон
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1F2937),
                    const Color(0xFF374151),
                  ]
                : [
                    const Color(0xFF1F2937),
                    const Color(0xFF374151),
                    const Color(0xFF4B5563),
                  ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFF97316),
                  ),
                )
              : _workout == null
                  ? Center(
                      child: Text(
                        'workout.not_found'.tr(),
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    )
                  : Column(
                      children: [
                        // Header
                        _buildHeader(),

                        // Контент
                        Expanded(
                          child: _workout!.exercises.isEmpty
                              ? _buildEmptyState()
                              : _buildExercisesList(),
                        ),
                        // Нижние кнопки (Добавить упражнение, Завершить тренировку)
                        _buildBottomButtons(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFF97316).withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          // Кнопка назад
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          // Название тренировки
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _workout?.name ?? 'workout.title'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _workout?.date ?? '',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Пустое состояние
  // Пустое состояние (нет упражнений)
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Иконка
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF97316).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.fitness_center,
                size: 64,
                color: Color(0xFFF97316),
              ),
            ),
            const SizedBox(height: 24),
            // Текст
            Text(
              'workout.no_exercises'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'workout.add_first_exercise'.tr(),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

// Список упражнений
  Widget _buildExercisesList() {
    return Column(
      children: [
        // Скроллящийся список
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _workout!.exercises.length,
            itemBuilder: (context, index) {
              final exercise = _workout!.exercises[index];
              return _buildExerciseCard(exercise);
            },
          ),
        ),
      ],
    );
  }

  // Карточка одного упражнения
  Widget _buildExerciseCard(Exercise exercise) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      color: isDark ? const Color(0xFF1F2937) : const Color(0xFF374151),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFFF97316).withOpacity(0.3),
          width: 1,
        ),
      ),
      // ← ДОБАВИЛИ InkWell для обработки долгого нажатия
      child: InkWell(
        onLongPress: () =>
            _showDeleteExerciseDialog(exercise), // ← Долгое нажатие
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Название упражнения + кнопка редактирования
              Row(
                children: [
                  const Icon(
                    Icons.fitness_center,
                    color: Color(0xFFF97316),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // ← НОВАЯ КНОПКА РЕДАКТИРОВАНИЯ
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: Color(0xFFF97316),
                      size: 20,
                    ),
                    onPressed: () => _showEditExerciseDialog(exercise),
                    tooltip: 'workout.edit_exercise'
                        .tr(), // ← Подсказка при долгом нажатии
                  ),
                ],
              ),

              // Целевая мышца (если есть)
              if (exercise.targetMuscle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.radio_button_checked,
                      color: Colors.grey[500],
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      exercise.targetMuscle,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],

              // Список подходов
              if (exercise.sets.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF97316), height: 1),
                const SizedBox(height: 12),
                ...exercise.sets.asMap().entries.map((entry) {
                  final index = entry.key;
                  final set = entry.value;
                  return _buildSetItem(exercise, set, index);
                }).toList(),
              ],

              // Кнопка "Добавить подход"
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddSetDialog(exercise),
                  icon: const Icon(
                    Icons.add,
                    color: Color(0xFFF97316),
                    size: 20,
                  ),
                  label: Text(
                    'workout.add_set_button'.tr(),
                    style: const TextStyle(
                      color: Color(0xFFF97316),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFFF97316),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Элемент списка подходов
  Widget _buildSetItem(Exercise exercise, WorkoutSet set, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: set.isDone
            ? const Color(0xFF10B981).withOpacity(0.1)
            : const Color(0xFF4B5563).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: set.isDone
              ? const Color(0xFF10B981)
              : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleSetDone(exercise.id, set.id, !set.isDone),
        borderRadius: BorderRadius.circular(8),
        onLongPress: () => _showSetActionsMenu(exercise, set, index + 1),
        child: Row(
          children: [
            // Номер подхода
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: set.isDone
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF97316),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Повторы и вес
            Expanded(
              child: Text(
                '${set.reps} ${'workout.reps'.tr().toLowerCase()} × ${set.weight} ${'workout.kg'.tr()}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  decoration: set.isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            // Иконка галочки
            Icon(
              set.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: set.isDone ? const Color(0xFF10B981) : Colors.grey,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

// Отметить/снять отметку "выполнен"
  Future<void> _toggleSetDone(
      String exerciseId, String setId, bool isDone) async {
    await _service.updateSet(
      widget.workoutId,
      exerciseId,
      setId,
      isDone: isDone,
    );
    await _loadWorkout();
  }

  // Показать диалог добавления подхода
  Future<void> _showAddSetDialog(Exercise exercise) async {
    // Очищаем поля
    _repsController.clear();
    _weightController.clear();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFF97316),
            width: 2,
          ),
        ),
        title: Text(
          'workout.add_set_dialog_title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Поле "Повторы"
            TextField(
              controller: _repsController,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                hintText: 'workout.reps_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                labelText: 'workout.reps'.tr(),
                labelStyle: const TextStyle(color: Color(0xFFF97316)),
                prefixIcon: const Icon(
                  Icons.repeat,
                  color: Color(0xFFF97316),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Поле "Вес"
            TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                hintText: 'workout.weight_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                labelText: 'workout.weight'.tr() + ' (${'workout.kg'.tr()})',
                labelStyle: const TextStyle(color: Color(0xFFF97316)),
                prefixIcon: const Icon(
                  Icons.fitness_center,
                  color: Color(0xFFF97316),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Кнопка "Отмена"
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          // Кнопка "Добавить"
          ElevatedButton(
            onPressed: () {
              // Проверка повторов
              final reps = int.tryParse(_repsController.text.trim());
              if (reps == null || reps <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('workout.reps_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Проверка веса
              final weight = double.tryParse(_weightController.text.trim());
              if (weight == null || weight < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('workout.weight_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            child: Text('workout.add_set_button'.tr()),
          ),
        ],
      ),
    );

    // Если нажали "Добавить"
    if (result == true) {
      await _addSet(exercise.id);
    }
  }

// Добавить подход в базу
  Future<void> _addSet(String exerciseId) async {
    final reps = int.parse(_repsController.text.trim());
    final weight = double.parse(_weightController.text.trim());

    final success = await _service.addSet(
      widget.workoutId,
      exerciseId,
      reps: reps,
      weight: weight,
    );

    if (success) {
      await _loadWorkout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${'workout.add_set_button'.tr()}! $reps × $weight ${'workout.kg'.tr()}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  // Показать диалог добавления упражнения
  Future<void> _showAddExerciseDialog() async {
    // Очищаем поля
    _exerciseNameController.clear();
    _targetMuscleController.clear();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFF97316),
            width: 2,
          ),
        ),
        title: Text(
          'workout.add_exercise_dialog_title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Поле "Название упражнения"
            TextField(
              controller: _exerciseNameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151), // Тёмно-серый фон
                hintText: 'workout.exercise_name_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(
                  Icons.fitness_center,
                  color: Color(0xFFF97316),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Поле "Целевая мышца"
            TextField(
              controller: _targetMuscleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151), // Тёмно-серый фон
                hintText: 'workout.target_muscle_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(
                  Icons.radio_button_checked,
                  color: Colors.grey[500],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Кнопка "Отмена"
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          // Кнопка "Добавить"
          ElevatedButton(
            onPressed: () {
              if (_exerciseNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('workout.exercise_name_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: Text('workout.add_exercise'.tr()),
          ),
        ],
      ),
    );

    // Если нажали "Добавить"
    if (result == true) {
      await _addExercise();
    }
  }

// Добавить упражнение в базу
  Future<void> _addExercise() async {
    final name = _exerciseNameController.text.trim();
    final muscle = _targetMuscleController.text.trim();

    final success = await _service.addExercise(
      widget.workoutId,
      name: name,
      targetMuscle: muscle,
    );

    if (success) {
      await _loadWorkout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('$name - ${'workout.add_exercise'.tr().toLowerCase()}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  // Показать диалог подтверждения удаления упражнения
  Future<void> _showDeleteExerciseDialog(Exercise exercise) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Colors.red, // ← КРАСНАЯ рамка для опасного действия
            width: 2,
          ),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_rounded, // ← Иконка предупреждения
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'workout.delete_exercise_confirm'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'workout.delete_exercise_message'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            // Показываем название удаляемого упражнения
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.fitness_center,
                    color: Color(0xFFF97316),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Кнопка "Отмена"
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          // Кнопка "Удалить" (красная!)
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, // ← КРАСНАЯ кнопка
              foregroundColor: Colors.white,
            ),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );

    // Если пользователь подтвердил удаление
    if (result == true) {
      await _deleteExercise(exercise.id);
    }
  }

  // Удалить упражнение из тренировки
  Future<void> _deleteExercise(String exerciseId) async {
    final success = await _service.removeExercise(
      widget.workoutId,
      exerciseId,
    );

    if (success) {
      await _loadWorkout(); // ← Перезагружаем тренировку

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('workout.exercise_deleted'.tr()),
            backgroundColor: Colors.red, // ← Красный snackbar для удаления
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Показать диалог редактирования упражнения
  Future<void> _showEditExerciseDialog(Exercise exercise) async {
    // Заполняем поля текущими значениями
    _exerciseNameController.text = exercise.name;
    _targetMuscleController.text = exercise.targetMuscle;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFF97316),
            width: 2,
          ),
        ),
        title: Text(
          'workout.edit_exercise_dialog_title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Поле "Название упражнения"
            TextField(
              controller: _exerciseNameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                hintText: 'workout.exercise_name_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(
                  Icons.fitness_center,
                  color: Color(0xFFF97316),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Поле "Целевая мышца"
            TextField(
              controller: _targetMuscleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                hintText: 'workout.target_muscle_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(
                  Icons.radio_button_checked,
                  color: Colors.grey[500],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Кнопка "Отмена"
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          // Кнопка "Сохранить"
          ElevatedButton(
            onPressed: () {
              if (_exerciseNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('workout.exercise_name_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
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

    // Если нажали "Сохранить"
    if (result == true) {
      await _updateExercise(exercise.id);
    }
  }

  // Обновить упражнение
  Future<void> _updateExercise(String exerciseId) async {
    final name = _exerciseNameController.text.trim();
    final muscle = _targetMuscleController.text.trim();

    final success = await _service.updateExercise(
      widget.workoutId,
      exerciseId,
      name: name,
      targetMuscle: muscle,
    );

    if (success) {
      await _loadWorkout(); // ← Перезагружаем тренировку

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('workout.exercise_updated'.tr()),
            backgroundColor: const Color(0xFF10B981), // ← Зелёный (успех)
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Показать диалог подтверждения удаления подхода
  Future<void> _showDeleteSetDialog(
      Exercise exercise, WorkoutSet set, int setNumber) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_rounded,
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'workout.delete_set_confirm'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'workout.delete_set_message'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            // Показываем детали удаляемого подхода
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Номер подхода
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF97316),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$setNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Детали подхода
                  Expanded(
                    child: Text(
                      '${set.reps} ${'workout.reps'.tr().toLowerCase()} × ${set.weight} ${'workout.kg'.tr()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Кнопка "Отмена"
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          // Кнопка "Удалить" (красная)
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );

    // Если подтвердили удаление
    if (result == true) {
      await _deleteSet(exercise.id, set.id);
    }
  }

  // Удалить подход
  Future<void> _deleteSet(String exerciseId, String setId) async {
    final success = await _service.removeSet(
      widget.workoutId,
      exerciseId,
      setId,
    );

    if (success) {
      await _loadWorkout(); // ← Перезагружаем тренировку

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('workout.set_deleted'.tr()),
            backgroundColor: Colors.red, // ← Красный для удаления
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Показать меню выбора действия для подхода
  Future<void> _showSetActionsMenu(
      Exercise exercise, WorkoutSet set, int setNumber) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: set.isDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF97316),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$setNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${set.reps} ${'workout.reps'.tr().toLowerCase()} × ${set.weight} ${'workout.kg'.tr()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFF97316), height: 1),

            // Кнопка "Редактировать"
            ListTile(
              leading: Icon(
                Icons.edit,
                color: set.isDone ? Colors.grey : const Color(0xFFF97316),
              ),
              title: Text(
                'workout.edit_set'.tr(),
                style: TextStyle(
                  color: set.isDone ? Colors.grey : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: set.isDone
                  ? Text(
                      'workout.cannot_edit_completed'.tr(),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    )
                  : null,
              enabled: !set.isDone, // ← Отключаем если выполнен
              onTap: set.isDone
                  ? null
                  : () {
                      Navigator.pop(context); // Закрываем меню
                      _showEditSetDialog(exercise, set, setNumber);
                    },
            ),

            // Кнопка "Удалить"
            ListTile(
              leading: const Icon(
                Icons.delete,
                color: Colors.red,
              ),
              title: Text(
                'workout.delete_set'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // Закрываем меню
                _showDeleteSetDialog(exercise, set, setNumber);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Показать диалог редактирования подхода
  Future<void> _showEditSetDialog(
      Exercise exercise, WorkoutSet set, int setNumber) async {
    // Заполняем поля текущими значениями
    _repsController.text = set.reps.toString();
    _weightController.text = set.weight.toString();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFF97316),
            width: 2,
          ),
        ),
        title: Text(
          'workout.edit_set_dialog_title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Показываем номер подхода
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFF97316),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.fitness_center,
                    color: Color(0xFFF97316),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${'workout.add_set_button'.tr()} #$setNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Поле "Повторы"
            TextField(
              controller: _repsController,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                hintText: 'workout.reps_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                labelText: 'workout.reps'.tr(),
                labelStyle: const TextStyle(color: Color(0xFFF97316)),
                prefixIcon: const Icon(
                  Icons.repeat,
                  color: Color(0xFFF97316),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Поле "Вес"
            TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                hintText: 'workout.weight_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                labelText: 'workout.weight'.tr() + ' (${'workout.kg'.tr()})',
                labelStyle: const TextStyle(color: Color(0xFFF97316)),
                prefixIcon: const Icon(
                  Icons.fitness_center,
                  color: Color(0xFFF97316),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Кнопка "Отмена"
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          // Кнопка "Сохранить"
          ElevatedButton(
            onPressed: () {
              // Проверка повторов
              final reps = int.tryParse(_repsController.text.trim());
              if (reps == null || reps <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('workout.reps_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Проверка веса
              final weight = double.tryParse(_weightController.text.trim());
              if (weight == null || weight < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('workout.weight_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
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

    // Если нажали "Сохранить"
    if (result == true) {
      await _updateSet(exercise.id, set.id);
    }
  }

  // Обновить подход
  Future<void> _updateSet(String exerciseId, String setId) async {
    final reps = int.parse(_repsController.text.trim());
    final weight = double.parse(_weightController.text.trim());

    final success = await _service.updateSet(
      widget.workoutId,
      exerciseId,
      setId,
      reps: reps,
      weight: weight,
    );

    if (success) {
      await _loadWorkout(); // ← Перезагружаем тренировку

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('workout.set_updated'.tr()),
            backgroundColor: const Color(0xFF10B981), // ← Зелёный (успех)
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Показать диалог подтверждения завершения тренировки
  Future<void> _showFinishWorkoutDialog() async {
    // Считаем статистику
    final totalExercises = _workout!.exercises.length;
    final totalSets = _workout!.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );
    final completedSets = _workout!.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.where((s) => s.isDone).length,
    );

    // ← НОВОЕ: Считаем общий объём (вес × повторы для выполненных подходов)
    final totalVolume = _workout!.exercises.fold<double>(
      0.0,
      (sum, exercise) =>
          sum +
          exercise.sets
              .where((s) => s.isDone) // Только выполненные подходы
              .fold<double>(
                  0.0, (setSum, set) => setSum + (set.weight * set.reps)),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFF10B981), // ← Зелёная рамка (успех)
            width: 2,
          ),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Color(0xFF10B981),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'workout.finish_workout_confirm'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'workout.finish_workout_message'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // Статистика тренировки
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildStatRow(
                    Icons.fitness_center,
                    'Упражнений',
                    '$totalExercises',
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    Icons.repeat,
                    'Подходов',
                    '$completedSets / $totalSets',
                  ),
                  // ← НОВОЕ: Показываем общий объём
                  const SizedBox(height: 8),
                  _buildStatRow(
                    Icons.monitor_weight,
                    'Общий объём',
                    '${totalVolume.toStringAsFixed(0)} ${'workout.kg'.tr()}',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Кнопка "Отмена"
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          // Кнопка "Завершить" (зелёная)
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981), // ← Зелёный
              foregroundColor: Colors.white,
            ),
            child: Text('workout.finish'.tr()),
          ),
        ],
      ),
    );

    // Если подтвердили завершение
    if (result == true) {
      await _finishWorkout();
    }
  }

  // Вспомогательная функция для строки статистики
  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFF97316), size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

// Завершить тренировку
  Future<void> _finishWorkout() async {
    final success = await _service.finishWorkout(widget.workoutId);

    if (success) {
      if (mounted) {
        // Показываем уведомление
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('workout.workout_finished'.tr()),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981), // ← Зелёный
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        // Закрываем экран редактора и возвращаемся на главный экран
        Navigator.pop(context);
      }
    }
  }

  // Нижние кнопки (Добавить упражнение + Завершить тренировку)
  Widget _buildBottomButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFF374151),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFF97316).withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Кнопка "Добавить упражнение" (оранжевая)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddExerciseDialog,
                icon: const Icon(Icons.add_circle, size: 24),
                label: Text(
                  'workout.add_exercise'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316), // Оранжевый
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 12), // ← Отступ между кнопками

            // Кнопка "Завершить тренировку" (зелёная)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showFinishWorkoutDialog,
                icon: const Icon(Icons.check_circle, size: 24),
                label: Text(
                  'workout.finish_workout'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // ← ЗЕЛЁНЫЙ
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
