import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/exercise_template.dart';
import '../services/custom_exercise_service.dart';
import '../services/data_read_guard.dart';
import '../services/exercise_catalog_service.dart';
import '../services/exercise_image_service.dart';
import '../services/exercise_library_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_badge.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_search_field.dart';
import '../widgets/bottom_action_button.dart';
import '../widgets/exercise_info_button.dart';
import '../widgets/muscle_group_chips.dart';
import '../widgets/new_exercise_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/segmented_tab_switch.dart';
import 'exercise_picker_page.dart';

// Миниатюры (кадр 0 демо) у встроенных упражнений на вкладке «Все».
// false — вместо миниатюры значок группы мышц, как у своих упражнений.
const bool kShowExerciseThumbnails = true;

// Вкладки: «Все» (встроенные + свои) и «Мои» (только свои).
enum _LibraryTab { all, mine }

// «Библиотека упражнений» (Настройки): все упражнения с поиском и фильтром
// по группе, демо встроенных; свои упражнения — использование и действия
// (объединить, переименовать, сменить группу, удалить), создание нового.
class ExerciseLibraryPage extends StatefulWidget {
  const ExerciseLibraryPage({super.key});

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  final _service = CustomExerciseService();
  final _searchController = TextEditingController();

  _LibraryTab _tab = _LibraryTab.all;
  String _selectedGroup = 'all';
  List<ExerciseTemplate> _builtIn = [];
  // Свои упражнения (без скрытых дубликатов встроенных), самые используемые сверху
  List<CustomExerciseEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // loadEntries заодно убирает неиспользуемые дубликаты встроенных
    final entries = await _service.loadEntries();
    final builtIn = await ExerciseLibraryService().getBuiltInExercises();
    await ExerciseImageService().init();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _builtIn = builtIn;
      _isLoading = false;
    });
  }

  String _nameOf(ExerciseTemplate t) {
    final lang = context.locale.languageCode;
    return ExerciseCatalogService()
        .displayName(templateId: t.id, name: t.getName(lang), languageCode: lang);
  }

  String _groupText(String group) =>
      group.isNotEmpty ? 'workout.muscle_$group'.tr() : '—';

  // Поиск по названию на текущем языке: без регистра, «ё» = «е», без краевых пробелов
  bool _matchesQuery(ExerciseTemplate t) {
    final query = ExerciseCatalogService.normalize(_searchController.text);
    return query.isEmpty ||
        ExerciseCatalogService.normalize(_nameOf(t)).contains(query);
  }

  // «Все»: встроенные и свои вместе, по названию; у своих — запись с использованием
  List<(ExerciseTemplate, CustomExerciseEntry?)> get _allItems {
    final items = <(ExerciseTemplate, CustomExerciseEntry?)>[
      for (final t in _builtIn) (t, null),
      for (final e in _entries) (e.template, e),
    ].where((item) {
      final t = item.$1;
      final matchGroup =
          _selectedGroup == 'all' || t.muscleGroup == _selectedGroup;
      return matchGroup && _matchesQuery(t);
    }).toList();
    final lang = context.locale.languageCode;
    final names = {for (final item in items) item.$1.id: _nameOf(item.$1)};
    items.sort((a, b) => ExerciseCatalogService.compareNames(
        names[a.$1.id]!, names[b.$1.id]!, lang));
    return items;
  }

  // «Мои»: порядок из сервиса (самые используемые сверху)
  List<CustomExerciseEntry> get _mineItems =>
      _entries.where((e) => _matchesQuery(e.template)).toList();

  // «Грудь · Тренировки: 12 · Программы: 2» / «— · Не используется»
  String _subtitleOf(CustomExerciseEntry entry) {
    final groupText = _groupText(entry.template.muscleGroup);
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
            PageHeader(title: 'exercise_library.title'.tr()),
            if (!_isLoading) ...[
              SegmentedTabSwitch(
                options: [
                  SegmentedTabOption('exercise_library.tab_all'.tr(namedArgs: {
                    'count': '${_builtIn.length + _entries.length}',
                  })),
                  SegmentedTabOption('exercise_library.tab_mine'
                      .tr(namedArgs: {'count': '${_entries.length}'})),
                ],
                selectedIndex: _tab.index,
                onSelected: (index) =>
                    setState(() => _tab = _LibraryTab.values[index]),
              ),
              AppSearchField(
                controller: _searchController,
                hintText: 'exercise_library.search_hint'.tr(),
              ),
              const SizedBox(height: 10),
              if (_tab == _LibraryTab.all) ...[
                MuscleGroupChips(
                  selected: _selectedGroup,
                  onSelected: (key) => setState(() => _selectedGroup = key),
                ),
                const SizedBox(height: 10),
              ],
            ],
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent))
                  : _tab == _LibraryTab.all
                      ? _buildAllList()
                      : _buildMineList(),
            ),
            // Под списком, а не поверх — последний элемент не закрывается
            if (!_isLoading && _tab == _LibraryTab.mine)
              BottomActionButton(
                icon: Icons.add,
                label: 'exercise_library.new_exercise'.tr(),
                onPressed: _createExercise,
              ),
          ],
        ),
      ),
    );
  }

  // Ключ — у каждой вкладки своя прокрутка (после переключения список сверху)
  Widget _buildAllList() {
    final items = _allItems;
    if (items.isEmpty) return _buildNothingFound();
    return ListView.builder(
      key: const ValueKey(_LibraryTab.all),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _buildLibraryItem(items[index].$1, items[index].$2),
    );
  }

  Widget _buildMineList() {
    if (_entries.isEmpty) return _buildEmpty();
    final items = _mineItems;
    if (items.isEmpty) return _buildNothingFound();
    return ListView.builder(
      key: const ValueKey(_LibraryTab.mine),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildMineItem(items[index]),
    );
  }

  // Слева в строке «Все»: миниатюра у встроенного (если включены и есть кадр),
  // иначе значок группы мышц. С миниатюрами место одной ширины — названия
  // встроенных и своих начинаются ровно.
  Widget _buildLeading(ExerciseTemplate t, {required bool isCustom}) {
    final icon = MuscleGroupIcon(group: t.muscleGroup);
    if (!kShowExerciseThumbnails) return icon;
    final paths = isCustom ? null : ExerciseImageService().imagePaths(id: t.id);
    return SizedBox(
      width: 44,
      child: paths == null
          ? Center(child: icon)
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                paths[0],
                width: 44,
                height: 30,
                fit: BoxFit.cover,
                // Декодируем в размере миниатюры, а не всего кадра
                cacheWidth:
                    (44 * MediaQuery.devicePixelRatioOf(context)).round(),
                errorBuilder: (_, __, ___) => Center(child: icon),
              ),
            ),
    );
  }

  // Строка вкладки «Все». Встроенное — нажатие / ⓘ открывает демо;
  // своё — метка «СВОЁ», нажатие открывает меню действий, как в «Мои».
  Widget _buildLibraryItem(ExerciseTemplate t, CustomExerciseEntry? entry) {
    final isCustom = entry != null;
    final name = _nameOf(t);
    return GestureDetector(
      onTap: () => isCustom ? _showActions(entry) : _openDemo(t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildLeading(t, isCustom: isCustom),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _groupText(t.muscleGroup),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Та же высота, что у ⓘ — строки одной высоты
            if (isCustom)
              SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 6),
                  child: Center(
                    child: AppBadge(
                      label: 'exercise_library.custom_badge'.tr(),
                      color: AppColors.program,
                    ),
                  ),
                ),
              )
            else
              ExerciseInfoButton(templateId: t.id, name: name),
          ],
        ),
      ),
    );
  }

  void _openDemo(ExerciseTemplate t) {
    final template = ExerciseImageService().findTemplate(id: t.id);
    if (template != null) showExerciseDemoSheet(context, template);
  }

  // Строка вкладки «Мои»: группа и использование, меню действий
  Widget _buildMineItem(CustomExerciseEntry entry) {
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
            MuscleGroupIcon(group: entry.template.muscleGroup),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameOf(entry.template),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

  // Своих упражнений нет (кнопка «Новое упражнение» — внизу экрана)
  Widget _buildEmpty() {
    return _buildMessage(
      icon: Icons.fitness_center,
      title: 'my_exercises.empty'.tr(),
      hint: 'my_exercises.empty_hint'.tr(),
    );
  }

  Widget _buildNothingFound() {
    return _buildMessage(
      icon: Icons.search_off,
      title: 'exercise_library.nothing_found'.tr(),
    );
  }

  // Прокручивается — на низком экране с клавиатурой не переполняется
  Widget _buildMessage(
      {required IconData icon, required String title, String? hint}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.textMuted, size: 48),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              if (hint != null) ...[
                const SizedBox(height: 6),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Новое упражнение: остаёмся на «Моих», поиск сбрасываем, чтобы
  // новое упражнение было видно в списке
  Future<void> _createExercise() async {
    final result = await showNewExerciseDialog(context);
    if (result == null || !mounted) return;
    _searchController.clear();
    setState(() => _tab = _LibraryTab.mine);
    await _load();
    if (mounted) _showSnack('exercise_library.added'.tr());
  }

  // Нижнее меню действий; выбранное действие выполняем после закрытия меню
  Future<void> _showActions(CustomExerciseEntry entry) async {
    final used = entry.usage.isUsed;
    final action = await showAppBottomSheet<String>(
      context: context,
      builder: (sheetContext) => [
        AppSheetHeader(
          leading: MuscleGroupIcon(group: entry.template.muscleGroup),
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
    } on DataReadException {
      // Данные не прочитались — объединение не начато, ничего не изменено
      if (mounted) {
        _showSnack('my_exercises.merge_read_error'.tr(),
            color: AppColors.danger);
      }
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
              leading: MuscleGroupIcon(group: key),
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

    final bool deleted;
    try {
      deleted = await _service.delete(entry.template.id);
    } on DataReadException {
      // Данные не прочитались — ничего не удалено
      if (mounted) {
        _showSnack('my_exercises.delete_read_error'.tr(),
            color: AppColors.danger);
      }
      return;
    }
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
