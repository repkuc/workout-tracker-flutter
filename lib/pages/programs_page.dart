// Подключаем базовые виджеты Flutter (Scaffold, Container, Text и т.д.).
import 'package:flutter/material.dart';

// Подключаем easy_localization для переводов через .tr().
import 'package:easy_localization/easy_localization.dart';

// Подключаем нашу модель программы.
import '../models/program_models.dart';

// Подключаем сервис для загрузки/сохранения программ.
import '../services/program_service.dart';
import '../models/builtin_program.dart';
import '../services/builtin_program_service.dart';
import '../services/workout_service.dart';
import 'builtin_program_page.dart';

// Подключаем экран создания программы, чтобы можно было на него перейти.
import 'create_program_page.dart';
// Подключаем экран деталей программы, чтобы можно было на него перейти.
import 'program_details_page.dart';
import '../theme/app_colors.dart';
import '../widgets/tab_header.dart';
import '../widgets/weekday_selector.dart';

// Вкладки вверху экрана: «Мои» и «Готовые».
enum _ProgramsTab { my, builtin }

// StatefulWidget — потому что страница должна загружать данные асинхронно
// и обновлять экран когда данные придут (в отличие от StatelessWidget).
class ProgramsPage extends StatefulWidget {
  // Видна ли вкладка «Программы» сейчас (передаёт MainPage). При показе
  // список перезагружается и пересортировывается, «Готовые» отмечаются просмотренными.
  final bool isActive;

  const ProgramsPage({super.key, this.isActive = false});

  @override
  State<ProgramsPage> createState() => _ProgramsPageState();
}

class _ProgramsPageState extends State<ProgramsPage> {
  // Выбранная вкладка, пока приложение запущено. static — переживает
  // пересоздание страницы (смена языка пересоздаёт все вкладки).
  // null — вкладку «Программы» ещё не показывали: тогда «Готовые»,
  // если своих программ нет, иначе «Мои».
  static _ProgramsTab? _savedTab;

  // Экземпляр сервиса для работы с программами.
  final _service = ProgramService();

  // Свои программы в порядке показа (по свежести, см. _sortByFreshness).
  List<TrainingProgram> _programs = [];

  // id программы → время последней тренировки (считается, не хранится).
  Map<String, DateTime> _lastWorkoutAt = {};

  // Готовые программы из assets (вкладка «Готовые»).
  List<BuiltinProgram> _builtinPrograms = [];

  // Есть готовая программа, которую ещё не видели — точка на «Готовых».
  bool _hasUnseenBuiltin = false;

  // Флаг — идёт ли сейчас загрузка данных (для показа спиннера).
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Как только страница создаётся — сразу начинаем загружать программы.
    _loadPrograms();
    // Тренировки изменились (завершили, удалили, импорт) — пересортировать
    WorkoutService().dataChanged.addListener(_loadPrograms);
  }

  @override
  void dispose() {
    WorkoutService().dataChanged.removeListener(_loadPrograms);
    super.dispose();
  }

  // Вкладку «Программы» открыли — перезагрузить (свежесть могла измениться).
  @override
  void didUpdateWidget(ProgramsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _loadPrograms();
  }

  // Текущая вкладка (см. _savedTab).
  _ProgramsTab get _tab =>
      _savedTab ?? (_programs.isEmpty ? _ProgramsTab.builtin : _ProgramsTab.my);

  // didChangeDependencies вызывается когда страница снова становится видимой
  // (например когда возвращаемся назад после создания программы).
  // Это гарантирует что список всегда актуальный.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPrograms();
  }

  // Загружаем список программ через сервис и обновляем состояние экрана.
  Future<void> _loadPrograms() async {
    final programs = await _service.loadAllPrograms();
    final lastWorkoutAt =
        await WorkoutService().getLastWorkoutTimesForPrograms(programs);
    final builtinPrograms = await BuiltinProgramService().loadPrograms();
    final hasUnseen = await BuiltinProgramService().hasUnseenPrograms();
    if (!mounted) return;
    // setState говорит Flutter "данные изменились, перерисуй экран".
    setState(() {
      _programs = _sortByFreshness(programs, lastWorkoutAt);
      _lastWorkoutAt = lastWorkoutAt;
      _builtinPrograms = builtinPrograms;
      _hasUnseenBuiltin = hasUnseen;
      _isLoading = false;
    });
    if (widget.isActive) {
      // Первый показ — запоминаем вкладку по умолчанию
      _savedTab ??= _tab;
      if (_tab == _ProgramsTab.builtin) _markBuiltinSeen();
    }
  }

  // Свежесть программы = позднее из «создана» и «последняя тренировка»
  // (правка программы не считается). Сначала программы со свежестью,
  // новые выше; без неё — ниже, в сохранённом порядке. Сортировка только
  // для показа, порядок в хранилище не меняем.
  List<TrainingProgram> _sortByFreshness(
      List<TrainingProgram> programs, Map<String, DateTime> lastWorkoutAt) {
    DateTime? freshness(TrainingProgram p) {
      final created = p.createdAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(p.createdAt!);
      final trained = lastWorkoutAt[p.id];
      if (created == null) return trained;
      if (trained == null) return created;
      return trained.isAfter(created) ? trained : created;
    }

    // List.sort не стабильная — при равенстве сравниваем исходный индекс
    final entries = [
      for (var i = 0; i < programs.length; i++) (i, freshness(programs[i])),
    ];
    entries.sort((a, b) {
      final (ai, ak) = a;
      final (bi, bk) = b;
      if (ak != null && bk != null) {
        final byTime = bk.compareTo(ak);
        if (byTime != 0) return byTime;
      } else if (ak != null) {
        return -1;
      } else if (bk != null) {
        return 1;
      }
      return ai.compareTo(bi);
    });
    return [for (final (i, _) in entries) programs[i]];
  }

  // Переключить вкладку (выбор держится, пока приложение запущено).
  void _selectTab(_ProgramsTab tab) {
    setState(() => _savedTab = tab);
    if (tab == _ProgramsTab.builtin) _markBuiltinSeen();
  }

  // Вкладку «Готовые» показали — все текущие готовые программы просмотрены.
  Future<void> _markBuiltinSeen() async {
    if (!_hasUnseenBuiltin) return;
    await BuiltinProgramService().markAllSeen();
    if (mounted) setState(() => _hasUnseenBuiltin = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Заголовок страницы — такой же стиль как на других страницах.
            _buildHeader(),

            // Переключатель «Мои | Готовые» (после загрузки — нужны счётчики).
            if (!_isLoading) _buildTabSwitch(),

            // Основной контент занимает всё оставшееся место.
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent),
                    )
                  : _tab == _ProgramsTab.my
                      ? _buildMyPrograms()
                      : _buildBuiltinPrograms(),
            ),

            // Кнопка "Создать программу" внизу экрана.
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  // Заголовок с иконкой и названием раздела.
  Widget _buildHeader() {
    return TabHeader(icon: Icons.assignment, title: 'programs.title'.tr());
  }

  // Переключатель вкладок «Мои (N) | Готовые (N)».
  Widget _buildTabSwitch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _buildTabOption(
              _ProgramsTab.my,
              'programs.tab_my'
                  .tr(namedArgs: {'count': '${_programs.length}'}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTabOption(
              _ProgramsTab.builtin,
              'programs.tab_builtin'
                  .tr(namedArgs: {'count': '${_builtinPrograms.length}'}),
              showDot: _hasUnseenBuiltin,
            ),
          ),
        ],
      ),
    );
  }

  // Одна половина переключателя — в стиле чипов дней недели.
  // showDot — оранжевая точка «есть новое».
  Widget _buildTabOption(_ProgramsTab tab, String label,
      {bool showDot = false}) {
    final selected = _tab == tab;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectTab(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.chipBorder,
            ),
          ),
          // Длинная подпись уменьшается, а не переносится
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.inactive,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (showDot) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Пустое состояние «Моих» — у пользователя ещё нет ни одной программы.
  // Кнопка ведёт на вкладку «Готовые». Прокручивается на очень низком экране.
  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: _buildEmptyStateContent(),
        ),
      ),
    );
  }

  Widget _buildEmptyStateContent() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment,
                size: 48, color: AppColors.accent),
          ),
          const SizedBox(height: 16),
          Text(
            'programs.no_programs'.tr(),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'programs.create_first'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _selectTab(_ProgramsTab.builtin),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              'programs.browse_builtin'.tr(),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Вкладка «Мои»: свои программы по свежести или пустое состояние.
  // Ключ — у каждой вкладки своя прокрутка (после переключения список сверху).
  Widget _buildMyPrograms() {
    if (_programs.isEmpty) return _buildEmptyState();
    return ListView(
      key: const ValueKey(_ProgramsTab.my),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: _programs.map(_buildProgramCard).toList(),
    );
  }

  // Вкладка «Готовые»: карточки готовых программ.
  Widget _buildBuiltinPrograms() {
    return ListView(
      key: const ValueKey(_ProgramsTab.builtin),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: _builtinPrograms.map(_buildBuiltinProgramCard).toList(),
    );
  }

  // «Последняя тренировка: сегодня / вчера / N дн. назад», больше 30 дней —
  // дата. Считаем календарные дни, а не по 24 часа.
  String _lastWorkoutText(DateTime time) {
    final now = DateTime.now();
    final local = time.toLocal();
    // Через UTC-даты — переход на летнее время не сбивает разницу
    final days = DateTime.utc(now.year, now.month, now.day)
        .difference(DateTime.utc(local.year, local.month, local.day))
        .inDays;
    final String when;
    if (days <= 0) {
      when = 'programs.last_workout_today'.tr();
    } else if (days == 1) {
      when = 'programs.last_workout_yesterday'.tr();
    } else if (days <= 30) {
      when = 'programs.last_workout_days_ago'
          .tr(namedArgs: {'count': '$days'});
    } else {
      when = DateFormat('dd.MM.yyyy').format(local);
    }
    return 'programs.last_workout'.tr(namedArgs: {'when': when});
  }

  // Карточка готовой программы: как своя, но с меткой «ГОТОВАЯ»;
  // дни, упражнения и дни недели. Нажатие — просмотр.
  Widget _buildBuiltinProgramCard(BuiltinProgram program) {
    final lang = context.locale.languageCode;

    return GestureDetector(
      onTap: () => _openBuiltinProgram(program),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    program.name(lang),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.accent),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'programs.builtin_badge'.tr(),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'programs.builtin_summary'.tr(namedArgs: {
                'days': '${program.days.length}',
                'exercises': '${program.exerciseCount}',
              }),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            if (program.scheduleDays.isNotEmpty) ...[
              const SizedBox(height: 10),
              ScheduleDayChips(days: program.scheduleDays),
            ],
          ],
        ),
      ),
    );
  }

  // Открыть просмотр готовой программы. Если её добавили в свои —
  // переходим на «Мои» (новая программа сверху — она самая свежая)
  // и показываем «Программа добавлена».
  Future<void> _openBuiltinProgram(BuiltinProgram program) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BuiltinProgramPage(program: program),
      ),
    );
    if (!mounted || added != true) return;
    setState(() => _savedTab = _ProgramsTab.my);
    await _loadPrograms();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('programs.program_added'.tr()),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // Одна карточка программы в списке.
  Widget _buildProgramCard(TrainingProgram program) {
    return GestureDetector(
      // Пока просто заглушка — переход на детали программы добавим следующим шагом.
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProgramDetailsPage(programId: program.id),
          ),
        );
        // Перезагружаем список на случай изменений
        _loadPrograms();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.accent.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Строка с названием программы и, если она своя, бейджем "СВОЯ".
            Row(
              children: [
                Expanded(
                  child: Text(
                    program.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (program.isCustom)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.program.withOpacity(0.15),
                      border: Border.all(color: AppColors.program),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'programs.custom_badge'.tr(),
                      style: const TextStyle(
                        color: AppColors.program,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            // Дни недели («Пн · Ср · Пт» / «Каждый день») — только если выбраны.
            if (program.scheduleDays.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: AppColors.textMuted, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    formatScheduleDays(program.scheduleDays),
                    style:
                        const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],

            // Последняя тренировка программы — только если она была.
            if (_lastWorkoutAt[program.id] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.history,
                      color: AppColors.textMuted, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _lastWorkoutText(_lastWorkoutAt[program.id]!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Чипсы с названиями дней/тренировок внутри программы.
            // Wrap автоматически переносит чипсы на новую строку если не помещаются.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: program.workouts.map((w) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    border: Border.all(
                        color: AppColors.accent.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    w.name,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Кнопка создания новой программы внизу экрана.
  Widget _buildCreateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          //
          onPressed: () async {
            final countBefore = _programs.length;
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CreateProgramPage()),
            );
            // После возврата с экрана создания — перезагружаем список,
            // чтобы новая программа сразу появилась; если её создали —
            // переходим на «Мои» (она сверху как самая свежая).
            await _loadPrograms();
            if (mounted && _programs.length > countBefore) {
              setState(() => _savedTab = _ProgramsTab.my);
            }
          },
          icon: const Icon(Icons.add, size: 20),
          label: Text(
            'programs.create_program'.tr(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
