import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/program_models.dart';
import '../theme/app_colors.dart';
import 'step_button.dart';

// План упражнения программы для диалога дня:
//      Подходы [−][3][+]
//   Повторы от [−][8][+]
//           до [−][12][+]
// Пишет значения прямо в exercise.targetSets / repsMin / repsMax (диалог дня
// работает с копией упражнения). Окончательно правило 1 ≤ от ≤ до ≤ 100 применяет
// exercise.normalizeRepsRange() при сохранении дня.
// Подписи — одна колонка общей ширины (по самой длинной), всегда в одну строку;
// если места мало, подпись немного уменьшается, а не переносится.
// На широком экране группы встают в одну строку (Wrap).
class ExercisePlanEditor extends StatefulWidget {
  final ProgramExercise exercise;

  const ExercisePlanEditor({super.key, required this.exercise});

  @override
  State<ExercisePlanEditor> createState() => _ExercisePlanEditorState();
}

class _ExercisePlanEditorState extends State<ExercisePlanEditor> {
  // С чего начинает «+» на пустом поле
  static const int _defaultFrom = 8;
  static const int _defaultTo = 12;
  static const int _maxReps = 100;

  // Подходы: 1…10
  static const int _minSets = 1;
  static const int _maxSets = 10;

  // Подписи: стиль и предельная ширина колонки
  static const TextStyle _labelStyle =
      TextStyle(color: AppColors.textMuted, fontSize: 12);
  static const double _maxLabelWidth = 96;

  late final TextEditingController _fromController;
  late final TextEditingController _toController;

  ProgramExercise get _ex => widget.exercise;

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(text: _ex.repsMin?.toString() ?? '');
    _toController = TextEditingController(text: _ex.repsMax?.toString() ?? '');
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  // Записать число в поле (null — пустое поле), курсор — в конец
  void _setText(TextEditingController controller, int? value) {
    final text = value?.toString() ?? '';
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  // Подходы ± 1 в пределах 1…10
  bool _stepSets(int delta) {
    final next = (_ex.targetSets + delta).clamp(_minSets, _maxSets);
    if (next == _ex.targetSets) return false;
    setState(() => _ex.targetSets = next);
    return true;
  }

  // «От»: пустое + → 8, − на 1 очищает поле. Если «от» стало больше «до» — «до» = «от».
  bool _stepFrom(int delta) {
    final current = _ex.repsMin;
    int? next;
    if (current == null) {
      if (delta < 0) return false;
      next = _defaultFrom;
    } else if (delta < 0 && current <= 1) {
      next = null;
    } else {
      next = (current + delta).clamp(1, _maxReps);
    }
    if (next == current) return false;

    _ex.repsMin = next;
    _setText(_fromController, next);
    final to = _ex.repsMax;
    if (next != null && to != null && next > to) {
      _ex.repsMax = next;
      _setText(_toController, next);
    }
    return true;
  }

  // «До»: пустое + → значение «от» (или 12), − на 1 очищает поле. Ниже «от» не опускается.
  bool _stepTo(int delta) {
    final current = _ex.repsMax;
    final from = _ex.repsMin;
    int? next;
    if (current == null) {
      if (delta < 0) return false;
      next = from ?? _defaultTo;
    } else if (delta < 0 && current <= 1) {
      next = null;
    } else {
      next = (current + delta).clamp(1, _maxReps);
      if (from != null && next < from) next = from;
    }
    if (next == current) return false;

    _ex.repsMax = next;
    _setText(_toController, next);
    return true;
  }

  Widget _buildField(TextEditingController controller, ValueChanged<int?> onChanged) {
    return SizedBox(
      width: 40,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (text) => onChanged(int.tryParse(text)),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          // Строка упражнения — surfaceInset (0F172A), поле должно отличаться от неё
          fillColor: AppColors.inputFillOnPage,
          hintText: '–',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // Подходов — просто число (без ввода с клавиатуры), меняется только кнопками
  Widget _buildSetsValue() {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.inputFillOnPage,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${_ex.targetSets}',
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }

  // Ширина колонки подписей — по самой длинной подписи (с учётом размера шрифта
  // в настройках телефона), но не больше _maxLabelWidth
  double _labelWidth(BuildContext context, List<String> labels) {
    double widest = 0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: _labelStyle),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return (widest.ceilToDouble() + 2).clamp(0, _maxLabelWidth).toDouble();
  }

  // Строка «подпись [−][значение][+]»; подпись прижата вправо к кнопкам,
  // в одну строку, при нехватке места уменьшается (FittedBox), а не переносится
  Widget _buildGroup({
    required String label,
    required double labelWidth,
    required Widget value,
    required bool Function(int delta) onStep,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: labelWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: _labelStyle,
            ),
          ),
        ),
        StepButton(
          icon: Icons.remove,
          semanticLabel: 'workout.decrease'.tr(),
          onStep: () => onStep(-1),
        ),
        value,
        StepButton(
          icon: Icons.add,
          semanticLabel: 'workout.increase'.tr(),
          onStep: () => onStep(1),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final setsLabel = 'programs.sets_label'.tr();
    final fromLabel = 'programs.reps_from_label'.tr();
    final toLabel = 'programs.reps_to'.tr();
    final labelWidth = _labelWidth(context, [setsLabel, fromLabel, toLabel]);

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildGroup(
          label: setsLabel,
          labelWidth: labelWidth,
          value: _buildSetsValue(),
          onStep: _stepSets,
        ),
        _buildGroup(
          label: fromLabel,
          labelWidth: labelWidth,
          value: _buildField(_fromController, (v) => _ex.repsMin = v),
          onStep: _stepFrom,
        ),
        _buildGroup(
          label: toLabel,
          labelWidth: labelWidth,
          value: _buildField(_toController, (v) => _ex.repsMax = v),
          onStep: _stepTo,
        ),
      ],
    );
  }
}
