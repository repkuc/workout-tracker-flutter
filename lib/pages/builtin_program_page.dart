import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/builtin_program.dart';
import '../services/builtin_program_service.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import '../widgets/program_exercise_row.dart';
import '../widgets/weekday_selector.dart';

// Просмотр готовой программы (только чтение): дни недели, описание целиком,
// дни с упражнениями. Кнопок «Начать» / «Повторить» / правки нет —
// внизу только «Добавить в мои программы». После добавления экран
// закрывается с результатом true (список программ обновит себя и покажет snackbar).
class BuiltinProgramPage extends StatefulWidget {
  final BuiltinProgram program;

  const BuiltinProgramPage({super.key, required this.program});

  @override
  State<BuiltinProgramPage> createState() => _BuiltinProgramPageState();
}

class _BuiltinProgramPageState extends State<BuiltinProgramPage> {
  // Идёт сохранение — кнопка неактивна (защита от двойного нажатия).
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      // SafeArea снизу — кнопка не уходит под системную панель навигации.
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(title: widget.program.name(lang)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  if (widget.program.scheduleDays.isNotEmpty) ...[
                    ScheduleDayChips(days: widget.program.scheduleDays),
                    const SizedBox(height: 12),
                  ],
                  _buildDescription(lang),
                  Text(
                    '${'programs.workouts_in_program'.tr()} (${widget.program.days.length})',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  ...widget.program.days.map((day) => _buildDayCard(day, lang)),
                ],
              ),
            ),
            _buildAddButton(lang),
          ],
        ),
      ),
    );
  }

  // Описание целиком (абзацы через пустую строку из файла).
  Widget _buildDescription(String lang) {
    final text = widget.program.description(lang).trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: const TextStyle(
            color: AppColors.textSoft, fontSize: 13, height: 1.35),
      ),
    );
  }

  // Карточка дня: название, количество упражнений и сами упражнения.
  Widget _buildDayCard(BuiltinProgramDay day, String lang) {
    final service = BuiltinProgramService();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day.name(lang),
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${day.exercises.length} ${'programs.exercises_count'.tr()}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          ...day.exercises.map((e) =>
              ProgramExerciseRow(exercise: service.toProgramExercise(e, lang))),
        ],
      ),
    );
  }

  Widget _buildAddButton(String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isAdding ? null : () => _addToMyPrograms(lang),
          icon: const Icon(Icons.add, size: 20),
          label: Text(
            'programs.add_to_my_programs'.tr(),
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

  // Копия на текущем языке → назад на вкладку «Программы» с результатом true.
  Future<void> _addToMyPrograms(String lang) async {
    setState(() => _isAdding = true);
    try {
      await BuiltinProgramService().addToMyPrograms(widget.program, lang);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'workout.error'.tr()}: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
