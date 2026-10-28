import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/exercise_template.dart';
import '../services/custom_exercise_service.dart';
import '../services/exercise_catalog_service.dart';
import '../services/exercise_library_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_dialog.dart';
import '../widgets/page_header.dart';
import 'exercise_picker_page.dart';

// «Мои упражнения» (Настройки): список своих упражнений с использованием
// и действия — объединить, переименовать, сменить группу, удалить.
class MyExercisesPage extends StatefulWidget {
  const MyExercisesPage({super.key});

  @override
  State<MyExercisesPage> createState() => _MyExercisesPageState();
}

class _MyExercisesPageState extends State<MyExercisesPage> {
  final _service = CustomExerciseService();

  List<CustomExerciseEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _service.loadEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  String _nameOf(ExerciseTemplate t) =>
      t.getName(context.locale.languageCode);

  // «Грудь · Тренировки: 12 · Программы: 2» / «— · Не используется»
  String _subtitleOf(CustomExerciseEntry entry) {
    final group = entry.template.muscleGroup;
    final groupText = group.isNotEmpty ? 'workout.muscle_$group'.tr() : '—';
    final usage = entry.usage;
    if (!usage.isUsed) return '$groupText · ${'my_exercises.not_used'.tr()}';
    return '$groupText · ${'my_exercises.usage'.tr(namedArgs: {
          'workouts': '${usage.workouts}',
          'programs': '${usage.programs}',
        })}';
  }

  void _showSnack(String text, {Color color = AppColors.success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'my_exercises.title'.tr(),
              subtitle: _isLoading || _entries.isEmpty
                  ? null
                  : 'my_exercises.count'
                      .tr(namedArgs: {'count': '${_entries.length}'}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent))
                  : _entries.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _entries.length,
                          itemBuilder: (context, index) =>
                              _buildItem(_entries[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleIcon(String group) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: group.isNotEmpty
          ? Image.asset(
              'assets/images/muscles/$group.png',
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center,
                  color: AppColors.accent, size: 18),
            )
          : const Icon(Icons.fitness_center,
              color: AppColors.accent, size: 18),
    );
  }

  Widget _buildItem(CustomExerciseEntry entry) {
    return GestureDetector(
      onTap: () => _showActions(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildMuscleIcon(entry.template.muscleGroup),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameOf(entry.template),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitleOf(entry),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              'my_exercises.empty'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'my_exercises.empty_hint'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // Нижнее меню действий; выбранное действие выполняем после закрытия меню
  Future<void> _showActions(CustomExerciseEntry entry) async {
    final used = entry.usage.isUsed;
    final action = await showAppBottomSheet<String>(
      context: context,
      builder: (sheetContext) => [
        AppSheetHeader(
          leading: _buildMuscleIcon(entry.template.muscleGroup),
          title: _nameOf(entry.template),
          bottom: Text(
            _subtitleOf(entry),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.merge_type, color: AppColors.accent),
          title: Text('my_exercises.merge'.tr(),
              style: const TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(sheetContext, 'merge'),
        ),
        ListTile(
          leading: const Icon(Icons.edit, color: AppColors.accent),
          title: Text('my_exercises.rename'.tr(),
              style: const TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(sheetContext, 'rename'),
        ),
        ListTile(
          leading: const Icon(Icons.accessibility_new, color: AppColors.accent),
          title: Text('my_exercises.change_group'.tr(),
              style: const TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(sheetContext, 'group'),
        ),
        // Удалить можно только неиспользуемое — иначе подсказываем «Объединить»
        ListTile(
          enabled: !used,
          leading: Icon(Icons.delete_outline,
              color: used ? AppColors.inactive : AppColors.danger),
          title: Text('my_exercises.delete'.tr(),
              style: TextStyle(
                  color: used ? AppColors.inactive : AppColors.danger)),
          subtitle: used
              ? Text('my_exercises.delete_used_hint'.tr(),
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12))
              : null,
          onTap: () => Navigator.pop(sheetContext, 'delete'),
        ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'merge':
        await _merge(entry);
      case 'rename':
        await _rename(entry);
      case 'group':
        await _changeGroup(entry);
      case 'delete':
        await _delete(entry);
    }
  }

  // Объединить: выбрать цель в библиотеке, подтвердить, перенести
  Future<void> _merge(CustomExerciseEntry entry) async {
    final picked = await Navigator.push<PickedExercise>(
      context,
      MaterialPageRoute(
        builder: (context) => ExercisePickerPage(
          title: 'my_exercises.merge_into_title'.tr(),
          excludeId: entry.template.id,
          allowAddCustom: false,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final target = picked.template;
    final targetName = _nameOf(target);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: Icons.merge_type,
        title: 'my_exercises.merge_confirm_title'.tr(),
        content: Text(
          'my_exercises.merge_confirm_message'.tr(namedArgs: {
            'source': _nameOf(entry.template),
            'target': targetName,
            'workouts': '${entry.usage.workouts}',
            'programs': '${entry.usage.programs}',
          }),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          AppDialogCancelButton(
            label: 'workout.cancel'.tr(),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AppDialogConfirmButton(
            label: 'my_exercises.merge_button'.tr(),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.merge(
        sourceId: entry.template.id,
        target: target,
        languageCode: context.locale.languageCode,
      );
      if (!mounted) return;
      _showSnack('my_exercises.merged'.tr(namedArgs: {'name': targetName}));
    } catch (e) {
      if (mounted) {
        _showSnack('${'workout.error'.tr()}: $e', color: AppColors.danger);
      }
    }
    await _load();
  }

  // Переименовать: пустое название или название другого упражнения —
  // ошибка прямо под полем (для второго случая подсказываем «Объединить»)
  Future<void> _rename(CustomExerciseEntry entry) async {
    final controller = TextEditingController(text: _nameOf(entry.template));
    String? nameError;

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AppDialog(
          icon: Icons.edit,
          title: 'my_exercises.rename_title'.tr(),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
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
            ],
          ),
          actions: [
            AppDialogCancelButton(
              label: 'workout.cancel'.tr(),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            AppDialogConfirmButton(
              label: 'workout.save'.tr(),
              onPressed: () {
                final text = controller.text;
                final conflict =
                    _service.renameConflict(entry.template.id, text);
                if (conflict == 'empty') {
                  setDialogState(() =>
                      nameError = 'workout.exercise_name_required'.tr());
                  return;
                }
                if (conflict != null) {
                  final other = ExerciseCatalogService().templateById(conflict);
                  setDialogState(() => nameError =
                      'my_exercises.name_taken'.tr(namedArgs: {
                        'name': other != null ? _nameOf(other) : text.trim(),
                      }));
                  return;
                }
                Navigator.pop(dialogContext, text.trim());
              },
            ),
          ],
        ),
      ),
    );
    if (newName == null || !mounted) return;
    if (newName == _nameOf(entry.template)) return;

    try {
      await _service.rename(entry.template.id, newName);
      if (mounted) _showSnack('my_exercises.renamed'.tr());
    } catch (e) {
      if (mounted) {
        _showSnack('${'workout.error'.tr()}: $e', color: AppColors.danger);
      }
    }
    await _load();
  }

  // Сменить группу мышц: одна из 6 групп
  Future<void> _changeGroup(CustomExerciseEntry entry) async {
    final current = entry.template.muscleGroup;
    final group = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'my_exercises.change_group'.tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ExerciseLibraryService.validGroups.map((key) {
            final isSelected = key == current;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _buildMuscleIcon(key),
              title: Text(
                'workout.muscle_$key'.tr(),
                style: TextStyle(
                  color: isSelected ? AppColors.accent : Colors.white,
                  fontSize: 14,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle,
                      color: AppColors.accent, size: 20)
                  : null,
              onTap: () => Navigator.pop(dialogContext, key),
            );
          }).toList(),
        ),
        actions: [
          AppDialogCancelButton(
            label: 'workout.cancel'.tr(),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
    if (group == null || group == current || !mounted) return;

    try {
      await _service.setMuscleGroup(entry.template.id, group);
      if (mounted) _showSnack('my_exercises.group_changed'.tr());
    } catch (e) {
      if (mounted) {
        _showSnack('${'workout.error'.tr()}: $e', color: AppColors.danger);
      }
    }
    await _load();
  }

  // Удалить неиспользуемое упражнение (с подтверждением)
  Future<void> _delete(CustomExerciseEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: Icons.delete_outline,
        iconColor: AppColors.danger,
        borderColor: AppColors.danger,
        title: 'my_exercises.delete_confirm_title'.tr(),
        content: Text(
          'my_exercises.delete_confirm_message'
              .tr(namedArgs: {'name': _nameOf(entry.template)}),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          AppDialogCancelButton(
            label: 'workout.cancel'.tr(),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AppDialogConfirmButton(
            label: 'workout.delete'.tr(),
            color: AppColors.danger,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final deleted = await _service.delete(entry.template.id);
    if (mounted) {
      _showSnack(
        deleted
            ? 'my_exercises.deleted'.tr()
            : 'my_exercises.delete_used_hint'.tr(),
        color: deleted ? AppColors.snackbarNeutral : AppColors.danger,
      );
    }
    await _load();
  }
}
