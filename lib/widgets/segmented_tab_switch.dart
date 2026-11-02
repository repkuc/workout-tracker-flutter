import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Одна половина переключателя: подпись и оранжевая точка «есть новое».
class SegmentedTabOption {
  final String label;
  final bool showDot;

  const SegmentedTabOption(this.label, {this.showDot = false});
}

// Переключатель вкладок вверху экрана («Мои (N) | Готовые (N)»,
// «Все (N) | Мои (N)») — половины в стиле чипов дней недели.
// Длинная подпись уменьшается, а не переносится.
class SegmentedTabSwitch extends StatelessWidget {
  final List<SegmentedTabOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const SegmentedTabSwitch({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _buildOption(i)),
          ],
        ],
      ),
    );
  }

  Widget _buildOption(int index) {
    final option = options[index];
    final selected = index == selectedIndex;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(index),
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  option.label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.inactive,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (option.showDot) ...[
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
}
