import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Шапка главной вкладки: оранжевый квадрат с иконкой + крупный заголовок.
// Все новые главные вкладки должны использовать этот виджет.
class TabHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  // Кнопки действий справа (необязательно).
  final Widget? trailing;

  // Нижний отступ — у некоторых вкладок он исторически отличается.
  final double bottomPadding;

  const TabHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.bottomPadding = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
