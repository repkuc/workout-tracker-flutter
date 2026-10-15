import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Шапка вложенного экрана: кнопка «назад» + заголовок в одну строку.
// Все новые вложенные экраны должны использовать этот виджет.
class PageHeader extends StatelessWidget {
  final String title;

  // Подзаголовок под названием (необязательно).
  final String? subtitle;

  // Кнопки действий справа (необязательно).
  final Widget? trailing;

  // Дополнительный блок под заголовком, например статистика тренировки.
  final Widget? bottom;

  // Тонкая оранжевая линия снизу шапки.
  final bool showDivider;

  // Своё действие кнопки «назад». По умолчанию — Navigator.pop(context).
  final VoidCallback? onBack;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottom,
    this.showDivider = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Отступ снизу больше, если под заголовком есть дополнительный блок
      padding: EdgeInsets.only(bottom: bottom != null ? 16 : 4),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.2), width: 1),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Слева 4, а не 16: IconButton сам даёт внутренний отступ,
          // поэтому стрелка визуально стоит на обычном краю экрана.
          Padding(
            padding: EdgeInsets.fromLTRB(4, 4, trailing != null ? 4 : 16, 0),
            child: Row(
              children: [
                // Кнопка «назад» с нормальной областью нажатия (48×48)
                IconButton(
                  onPressed: onBack ?? () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          if (bottom != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: bottom!,
            ),
        ],
      ),
    );
  }
}
