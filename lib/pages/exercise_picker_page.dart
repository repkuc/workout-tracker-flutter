import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/exercise_template.dart';
import '../services/exercise_library_service.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import '../widgets/app_dialog.dart';

class ExercisePickerPage extends StatefulWidget {
  const ExercisePickerPage({super.key});

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

  final List<String> _groups = [
    'all',
    'chest',
    'back',
    'legs',
    'shoulders',
    'arms',
    'abs',
  ];

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
    final exercises = await _libraryService.getAllExercises();
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
            PageHeader(title: 'workout.add_exercise'.tr()),

            // Поиск
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.inputFillOnPage,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.transparent,
                    hintText: 'workout.exercise_search_hint'.tr(),
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textMuted, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Табы групп мышц
            // Табы групп мышц
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _groups.length,
                itemBuilder: (context, index) {
                  final key = _groups[index];
                  final isSelected = _selectedGroup == key;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedGroup = key);
                      _applyFilter();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 6),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 12 : 8,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withOpacity(0.15)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          key == 'all'
                              ? Icon(
                                  Icons.fitness_center,
                                  color: isSelected
                                      ? AppColors.accent
                                      : AppColors.textMuted,
                                  size: 20,
                                )
                              // Картинка в своих цветах, как в списке упражнений;
                              // невыбранные вкладки — полупрозрачные
                              : Opacity(
                                  opacity: isSelected ? 1.0 : 0.5,
                                  child: Image.asset(
                                    'assets/images/muscles/$key.png',
                                    width: 22,
                                    height: 22,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.fitness_center,
                                      color: isSelected
                                          ? AppColors.accent
                                          : AppColors.textMuted,
                                      size: 20,
                                    ),
                                  ),
                                ),
                          if (isSelected) ...[
                            const SizedBox(height: 3),
                            Text(
                              key == 'all'
                                  ? 'workout.all_exercises'.tr()
                                  : 'workout.muscle_$key'.tr(),
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
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
                          itemCount:
                              _filtered.length + 1, // +1 для кнопки внизу
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
      onTap: () => Navigator.pop(context, exercise),
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: exercise.muscleGroup.isNotEmpty
                  ? Image.asset(
                      'assets/images/muscles/${exercise.muscleGroup}.png',
                      width: 24,
                      height: 24,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.fitness_center,
                        color: AppColors.accent,
                        size: 18,
                      ),
                    )
                  : const Icon(Icons.fitness_center,
                      color: AppColors.accent, size: 18),
            ),
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
          const SizedBox(height: 20),
          _buildAddCustomButton(),
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

  Future<void> _showAddCustomDialog() async {
    final nameController = TextEditingController();
    String selectedGroup = '';
    // Ошибку пустого названия показываем прямо под полем
    String? nameError;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          title: 'workout.add_custom_exercise'.tr(),
          content: Column(
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
                  labelText: 'workout.exercise_name'.tr(),
                  hintText: 'workout.exercise_name_hint'.tr(),
                  icon: Icons.fitness_center,
                  errorText: nameError,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'workout.muscle_groups'.tr(),
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'chest',
                  'back',
                  'legs',
                  'shoulders',
                  'arms',
                  'abs'
                ].map((key) {
                  final isSelected = selectedGroup == key;
                  return GestureDetector(
                    onTap: () => setDialogState(() {
                      selectedGroup = isSelected ? '' : key;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withOpacity(0.2)
                            : AppColors.surfaceInset,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.chipBorder,
                        ),
                      ),
                      child: Text(
                        'workout.muscle_$key'.tr(),
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            AppDialogCancelButton(
              label: 'workout.cancel'.tr(),
              onPressed: () => Navigator.pop(context, false),
            ),
            AppDialogConfirmButton(
              label: 'workout.add_exercise'.tr(),
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  setDialogState(() =>
                      nameError = 'workout.exercise_name_required'.tr());
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
      final name = nameController.text.trim();
      await _libraryService.addCustomExercise(
        nameRu: name,
        nameLv: name,
        nameEn: name,
        muscleGroup: selectedGroup,
      );
      await _loadExercises();

      // Сразу возвращаем добавленное упражнение
      if (mounted) {
        final newExercise = ExerciseTemplate(
          id: 'custom_temp',
          nameRu: name,
          nameLv: name,
          nameEn: name,
          muscleGroup: selectedGroup,
          isCustom: true,
        );
        Navigator.pop(context, newExercise);
      }
    }
  }
}
