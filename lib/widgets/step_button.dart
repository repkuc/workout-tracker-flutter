import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

// Кнопка «−» / «+» для быстрого изменения числа в поле (повторы, вес).
// Тап — один шаг; удержание — шаг повторяется, всё быстрее, пока держишь.
// Видимая часть 40×40, зона нажатия 48×48. Лёгкая вибрация на каждом шаге.
// onStep возвращает true, если значение изменилось (иначе без вибрации).
class StepButton extends StatefulWidget {
  final IconData icon;
  final String semanticLabel;
  final bool Function() onStep;

  const StepButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onStep,
  });

  @override
  State<StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<StepButton> {
  Timer? _repeatTimer;
  bool _pressed = false;

  // Интервал повтора при удержании: начинаем с 300 мс и ускоряемся до 60 мс
  static const int _startIntervalMs = 300;
  static const int _minIntervalMs = 60;

  void _step() {
    if (widget.onStep()) {
      HapticFeedback.selectionClick();
    }
  }

  void _startRepeat() {
    _step();
    _scheduleNext(_startIntervalMs);
  }

  void _scheduleNext(int intervalMs) {
    _repeatTimer?.cancel();
    _repeatTimer = Timer(Duration(milliseconds: intervalMs), () {
      if (!mounted) return;
      _step();
      // Каждый следующий шаг чуть быстрее предыдущего
      _scheduleNext((intervalMs * 0.85).round().clamp(_minIntervalMs, _startIntervalMs));
    });
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      // Listener не участвует в «арене» жестов — только подсветка нажатия
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _step,
          onLongPressStart: (_) => _startRepeat(),
          onLongPressEnd: (_) => _stopRepeat(),
          onLongPressCancel: _stopRepeat,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _pressed
                      ? AppColors.accent.withValues(alpha: 0.25)
                      : AppColors.inputFill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: _pressed ? 1 : 0.5),
                    width: 1,
                  ),
                ),
                child: Icon(widget.icon, color: AppColors.accent, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
