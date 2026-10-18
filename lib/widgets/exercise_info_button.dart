import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/exercise_template.dart';
import '../services/exercise_image_service.dart';
import '../theme/app_colors.dart';
import 'app_bottom_sheet.dart';

// Маленькая кнопка ⓘ рядом с названием упражнения. Открывает лист с
// демо-анимацией (два кадра по очереди). Если у упражнения нет картинок
// (пользовательское упражнение), кнопка не занимает места вообще.
// Использовать на любом экране, где показывается упражнение.
class ExerciseInfoButton extends StatelessWidget {
  // id шаблона, если он известен (экран выбора упражнения)
  final String? templateId;
  // Название упражнения на любом из трёх языков (так хранится в тренировках)
  final String? name;

  const ExerciseInfoButton({super.key, this.templateId, this.name});

  @override
  Widget build(BuildContext context) {
    final service = ExerciseImageService();
    if (!service.isLoaded) {
      // Обычно поиск уже построен в main; на всякий случай ждём его здесь
      return FutureBuilder<void>(
        future: service.init(),
        builder: (context, snapshot) =>
            snapshot.connectionState == ConnectionState.done
                ? _buildButton(context)
                : const SizedBox.shrink(),
      );
    }
    return _buildButton(context);
  }

  Widget _buildButton(BuildContext context) {
    final template =
        ExerciseImageService().findTemplate(id: templateId, name: name);
    if (template == null) return const SizedBox.shrink();

    // Сам значок маленький, но область нажатия 40×40.
    // IconButton забирает нажатие себе, поэтому onTap родителя не срабатывает.
    return IconButton(
      onPressed: () => showExerciseDemoSheet(context, template),
      icon: const Icon(Icons.info_outline, size: 18),
      color: AppColors.iconNeutral,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      tooltip: 'exercise_demo.show'.tr(),
    );
  }
}

// Лист с демонстрацией упражнения: название на текущем языке, группа мышц
// и картинка, которая чередует начальное и конечное положение.
Future<void> showExerciseDemoSheet(
    BuildContext context, ExerciseTemplate template) {
  final lang = context.locale.languageCode;
  final paths = ExerciseImageService().imagePaths(id: template.id)!;

  return showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) => [
      AppSheetHeader(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.asset(
            'assets/images/muscles/${template.muscleGroup}.png',
            width: 24,
            height: 24,
            errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center,
                color: AppColors.accent, size: 18),
          ),
        ),
        title: template.getName(lang),
        bottom: template.muscleGroup.isEmpty
            ? null
            : Text(
                'workout.muscle_${template.muscleGroup}'.tr(),
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
      ),
      // Flexible — чтобы на низком экране (альбомная ориентация) картинка
      // уменьшалась, а не вылезала за лист
      Flexible(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _ExerciseDemoAnimation(start: paths[0], end: paths[1]),
        ),
      ),
    ],
  );
}

// Чередует два кадра каждые ~0.6 с с коротким перетеканием.
// Таймер живёт, пока открыт лист, и останавливается в dispose.
class _ExerciseDemoAnimation extends StatefulWidget {
  final String start;
  final String end;

  const _ExerciseDemoAnimation({required this.start, required this.end});

  @override
  State<_ExerciseDemoAnimation> createState() => _ExerciseDemoAnimationState();
}

class _ExerciseDemoAnimationState extends State<_ExerciseDemoAnimation> {
  static const _frameDuration = Duration(milliseconds: 600);
  static const _fadeDuration = Duration(milliseconds: 150);

  Timer? _timer;
  int _frame = 0;
  // Пропорции картинки (ширина / высота); до загрузки — типичные 4:3
  double _aspect = 4 / 3;
  bool _precached = false;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_frameDuration, (_) {
      if (mounted) setState(() => _frame = 1 - _frame);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;

    // Заранее загружаем оба кадра, чтобы при смене не было мигания
    precacheImage(AssetImage(widget.start), context);
    precacheImage(AssetImage(widget.end), context);

    // Узнаём настоящие пропорции, чтобы скруглённая рамка совпадала с картинкой
    // (большинство кадров горизонтальные, но есть и вертикальные)
    _stream = AssetImage(widget.start)
        .resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _aspect = info.image.width / info.image.height);
    });
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ограничиваем высоту, чтобы лист не занимал весь экран
        final maxHeight = math.min(constraints.maxHeight, screenHeight * 0.4);
        var width = constraints.maxWidth;
        var height = width / _aspect;
        if (height > maxHeight) {
          height = maxHeight;
          width = height * _aspect;
        }
        final path = _frame == 0 ? widget.start : widget.end;

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AnimatedSwitcher(
                duration: _fadeDuration,
                // Кадры кладём друг на друга, чтобы перетекание было без скачков
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, if (current != null) current],
                ),
                child: Image.asset(
                  path,
                  key: ValueKey(path),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
