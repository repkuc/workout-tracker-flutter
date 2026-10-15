import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Открыть нижнее меню (bottom sheet) в общем стиле приложения:
// фон surface, скругление 20 сверху, «ручка» для перетаскивания, отступ снизу.
// Содержимое (обычно AppSheetHeader + пункты ListTile) возвращает builder.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required List<Widget> Function(BuildContext sheetContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // «Ручка» сверху — подсказка, что лист можно смахнуть вниз
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.sheetHandle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ...builder(sheetContext),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// Шапка нижнего меню: значок/кружок слева, заголовок, необязательная
// строка под заголовком (bottom) и разделитель снизу.
class AppSheetHeader extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Widget? bottom;

  const AppSheetHeader({
    super.key,
    this.leading,
    required this.title,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (bottom != null) ...[
                      const SizedBox(height: 4),
                      bottom!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.divider),
      ],
    );
  }
}
