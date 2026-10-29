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
import 'builtin_program_page.dart';

// Подключаем экран создания программы, чтобы можно было на него перейти.
import 'create_program_page.dart';
// Подключаем экран деталей программы, чтобы можно было на него перейти.
import 'program_details_page.dart';
import '../theme/app_colors.dart';
import '../widgets/tab_header.dart';
import '../widgets/weekday_selector.dart';

// StatefulWidget — потому что страница должна загружать данные асинхронно
// и обновлять экран когда данные придут (в отличие от StatelessWidget).
class ProgramsPage extends StatefulWidget {
  const ProgramsPage({super.key});

  @override
  State<ProgramsPage> createState() => _ProgramsPageState();
}

class _ProgramsPageState extends State<ProgramsPage> {
  // Экземпляр сервиса для работы с программами.
  final _service = ProgramService();

  // Список программ, который будет показан на экране.
  List<TrainingProgram> _programs = [];

  // Готовые программы из assets (секция под своими программами).
  List<BuiltinProgram> _builtinPrograms = [];

  // Флаг — идёт ли сейчас загрузка данных (для показа спиннера).
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Как только страница создаётся — сразу начинаем загружать программы.
    _loadPrograms();
  }

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
    final builtinPrograms = await BuiltinProgramService().loadPrograms();
    if (!mounted) return;
    // setState говорит Flutter "данные изменились, перерисуй экран".
    setState(() {
      _programs = programs;
      _builtinPrograms = builtinPrograms;
      _isLoading = false;
    });
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

            // Основной контент занимает всё оставшееся место.
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent),
                    )
                  : _buildProgramsList(),
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

  // Пустое состояние — когда у пользователя ещё нет ни одной программы.
  // Не по центру экрана, а сверху: сразу под ним видны готовые программы.
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
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
        ],
      ),
    );
  }

  // Список: свои программы (или пустое состояние), ниже — готовые программы.
  Widget _buildProgramsList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (_programs.isEmpty)
          _buildEmptyState()
        else
          ..._programs.map(_buildProgramCard),
        if (_builtinPrograms.isNotEmpty) ...[
          _buildBuiltinHeader(),
          ..._builtinPrograms.map(_buildBuiltinProgramCard),
        ],
      ],
    );
  }

  // Небольшой заголовок секции «Готовые программы».
  Widget _buildBuiltinHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.textMuted, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'programs.builtin_section'.tr(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
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
  // сразу обновляем список и показываем «Программа добавлена».
  Future<void> _openBuiltinProgram(BuiltinProgram program) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BuiltinProgramPage(program: program),
      ),
    );
    if (!mounted || added != true) return;
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
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CreateProgramPage()),
            );
            // После возврата с экрана создания — перезагружаем список,
            // чтобы новая программа сразу появилась.
            _loadPrograms();
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
