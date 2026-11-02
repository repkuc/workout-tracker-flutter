import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/exercise_template.dart';
import '../services/exercise_library_service.dart';
import '../services/exercise_catalog_service.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import '../widgets/app_search_field.dart';
import '../widgets/exercise_info_button.dart';
import '../widgets/muscle_group_chips.dart';
import '../widgets/new_exercise_dialog.dart';

// Результат выбора: шаблон и признак «такое упражнение уже было в библиотеке»
// (пользователь ввёл в «Добавить своё упражнение» название существующего).
// Сообщение об этом показывает вызывающий экран — сам выбор только что
// закрылся, а у диалога дня программы SnackBar оказался бы за его фоном.
class PickedExercise {
  final ExerciseTemplate template;
  final bool alreadyInLibrary;

  const PickedExercise(this.template, {this.alreadyInLibrary = false});
}

class ExercisePickerPage extends StatefulWidget {
  // Свой заголовок (null — «Добавить упражнение»)
  final String? title;
  // id упражнения, которое не показываем (при объединении — само упражнение)
  final String? excludeId;
  // Показывать ли кнопку «Добавить своё упражнение»
  final bool allowAddCustom;

  const ExercisePickerPage({
    super.key,
    this.title,
    this.excludeId,
    this.allowAddCustom = true,
  });

  @override
  State<ExercisePickerPage> createState() => _ExercisePickerPageState();
}

class _ExercisePickerPageState extends State<ExercisePickerPage> {
  final _libraryService = ExerciseLibraryService();
  final _searchController = TextEditingController();

  List<ExerciseTemplate> _exercises = [];
  List<ExerciseTemplate> _filtered = [];
  bool _isLoading = true;
  String _selectedGroup = 'all';

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);
    // Свои упражнения с названием встроенного (дубликаты от старой миграции) скрываем
    final catalog = ExerciseCatalogService();
    final exercises = (await _libraryService.getAllExercises())
        .where((e) => !catalog.isBuiltInDuplicate(e) && e.id != widget.excludeId)
        .toList();
    setState(() {
      _exercises = exercises;
      _isLoading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();
    final lang = context.locale.languageCode;

    setState(() {
      _filtered = _exercises.where((e) {
        final matchGroup = _selectedGroup == 'all' || e.muscleGroup == _selectedGroup;
        final matchQuery =
            query.isEmpty || e.getName(lang).toLowerCase().contains(query);
        return matchGroup && matchQuery;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Шапка
            PageHeader(title: widget.title ?? 'workout.add_exercise'.tr()),

            // Поиск
            AppSearchField(
              controller: _searchController,
              hintText: 'workout.exercise_search_hint'.tr(),
            ),

            const SizedBox(height: 10),

            // Табы групп мышц
            MuscleGroupChips(
              selected: _selectedGroup,
              onSelected: (key) {
                setState(() => _selectedGroup = key);
                _applyFilter();
              },
            ),

            const SizedBox(height: 10),

            // Список упражнений
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent))
                  : _filtered.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          // +1 для кнопки внизу
                          itemCount: _filtered.length +
                              (widget.allowAddCustom ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _filtered.length) {
                              return _buildAddCustomButton();
                            }
                            return _buildExerciseItem(_filtered[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseItem(ExerciseTemplate exercise) {
    final lang = context.locale.languageCode;
    final name = exercise.getName(lang);

    return GestureDetector(
      onTap: () => Navigator.pop(context, PickedExercise(exercise)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Иконка группы мышц
            MuscleGroupIcon(group: exercise.muscleGroup),
            const SizedBox(width: 12),

            // Название + группа мышц
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (exercise.muscleGroup.isNotEmpty)
                    Text(
                      'workout.muscle_${exercise.muscleGroup}'.tr(),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),

            // Иконка пользовательского упражнения
            if (exercise.isCustom)
              const Icon(Icons.person, color: AppColors.textMuted, size: 16),

            // Демо упражнения; нажатие не выбирает упражнение
            ExerciseInfoButton(templateId: exercise.id, name: name),

            const Icon(Icons.add_circle_outline,
                color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            'workout.no_exercises_found'.tr(),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          if (widget.allowAddCustom) ...[
            const SizedBox(height: 20),
            _buildAddCustomButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildAddCustomButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: _showAddCustomDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accent.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'workout.add_custom_exercise'.tr(),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Новое своё упражнение (общий диалог с библиотекой). Созданное сразу
  // возвращаем с настоящим id; если такое название уже есть — возвращаем
  // существующее, как будто его выбрали в списке (ничего не создаётся).
  Future<void> _showAddCustomDialog() async {
    final result = await showNewExerciseDialog(context,
        onExisting: NewExerciseOnExisting.useExisting);
    if (result != null && mounted) {
      Navigator.pop(context,
          PickedExercise(result.template, alreadyInLibrary: result.existed));
    }
  }
}

// Сообщение «… уже есть в библиотеке — добавлено» (название на текущем языке)
String alreadyInLibraryText(BuildContext context, ExerciseTemplate template) {
  final lang = context.locale.languageCode;
  return 'workout.exercise_already_in_library_added'.tr(namedArgs: {
    'name': ExerciseCatalogService().displayName(
        templateId: template.id,
        name: template.getName(lang),
        languageCode: lang),
  });
}
