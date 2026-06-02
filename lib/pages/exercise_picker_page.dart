import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/exercise_template.dart';
import '../services/exercise_library_service.dart';

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

  final List<Map<String, String>> _groups = [
    {'key': 'all', 'icon': '💪'},
    {'key': 'chest', 'icon': '🫁'},
    {'key': 'back', 'icon': '🔙'},
    {'key': 'legs', 'icon': '🦵'},
    {'key': 'shoulders', 'icon': '💪'},
    {'key': 'arms', 'icon': '🦾'},
    {'key': 'abs', 'icon': '⚡'},
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
        final matchGroup = _selectedGroup == 'all' ||
            e.muscleGroup == _selectedGroup ||
            (_selectedGroup != 'all' && e.muscleGroup.isEmpty);
        final matchQuery =
            query.isEmpty || e.getName(lang).toLowerCase().contains(query);
        return matchGroup && matchQuery;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Шапка
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'workout.add_exercise'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Поиск
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'workout.exercise_search_hint'.tr(),
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFF64748B), size: 20),
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
                  final key = _groups[index]['key']!;
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
                            ? const Color(0xFFF97316).withOpacity(0.15)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFF97316)
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
                                      ? const Color(0xFFF97316)
                                      : const Color(0xFF64748B),
                                  size: 20,
                                )
                              : Image.asset(
                                  'assets/images/muscles/$key.png',
                                  width: 22,
                                  height: 22,
                                  color: isSelected
                                      ? const Color(0xFFF97316)
                                      : const Color(0xFF64748B),
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.fitness_center,
                                    color: isSelected
                                        ? const Color(0xFFF97316)
                                        : const Color(0xFF64748B),
                                    size: 20,
                                  ),
                                ),
                          if (isSelected) ...[
                            const SizedBox(height: 3),
                            Text(
                              key == 'all'
                                  ? 'workout.all_exercises'.tr()
                                  : 'workout.muscle_$key'.tr(),
                              style: const TextStyle(
                                color: Color(0xFFF97316),
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
                          CircularProgressIndicator(color: Color(0xFFF97316)))
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
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Иконка группы мышц
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: exercise.muscleGroup.isNotEmpty
                  ? Image.asset(
                      'assets/images/muscles/${exercise.muscleGroup}.png',
                      width: 24,
                      height: 24,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.fitness_center,
                        color: Color(0xFFF97316),
                        size: 18,
                      ),
                    )
                  : const Icon(Icons.fitness_center,
                      color: Color(0xFFF97316), size: 18),
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
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),

            // Иконка пользовательского упражнения
            if (exercise.isCustom)
              const Icon(Icons.person, color: Color(0xFF64748B), size: 16),

            const Icon(Icons.add_circle_outline,
                color: Color(0xFFF97316), size: 20),
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
          const Icon(Icons.search_off, color: Color(0xFF64748B), size: 48),
          const SizedBox(height: 12),
          Text(
            'workout.no_exercises_found'.tr(),
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
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
            color: const Color(0xFFF97316).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFF97316).withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, color: Color(0xFFF97316), size: 20),
              const SizedBox(width: 8),
              Text(
                'workout.add_custom_exercise'.tr(),
                style: const TextStyle(
                  color: Color(0xFFF97316),
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

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFF97316), width: 1),
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text(
            'workout.add_custom_exercise'.tr(),
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    hintText: 'workout.exercise_name_hint'.tr(),
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.fitness_center,
                        color: Color(0xFFF97316), size: 18),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'workout.muscle_groups'.tr(),
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 11, letterSpacing: 1),
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
                              ? const Color(0xFFF97316).withOpacity(0.2)
                              : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFF97316)
                                : const Color(0xFF374151),
                          ),
                        ),
                        child: Text(
                          'workout.muscle_$key'.tr(),
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFFF97316)
                                : const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
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
                        content: Text('workout.exercise_name_required'.tr()),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text('workout.add_exercise'.tr()),
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
