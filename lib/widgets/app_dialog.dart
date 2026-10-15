import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Общая «оболочка» компактного диалога: заголовок (с иконкой или без),
// отступы, рамка, прокрутка содержимого. Кнопки — AppDialogCancelButton /
// AppDialogConfirmButton, поля ввода — appDialogInputDecoration().
// Новые диалоги должны собираться из этих частей, чтобы выглядели одинаково.
class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  // Иконка слева от заголовка (необязательно) и её цвет.
  final IconData? icon;
  final Color iconColor;

  // Цвет рамки: оранжевая обычно, красная для удаления, зелёная для завершения.
  final Color borderColor;

  // Отступы диалога от краёв экрана (null — стандартные).
  final EdgeInsets? insetPadding;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    this.iconColor = AppColors.accent,
    this.borderColor = AppColors.dialogBorder,
    this.insetPadding,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      insetPadding: insetPadding,
      titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      // Прокрутка — чтобы при открытой клавиатуре на низком экране
      // (например, складные телефоны) содержимое не наезжало на кнопки
      content: SingleChildScrollView(child: content),
      actions: actions,
    );
  }
}

// Кнопка «Отмена» / «Вернуться» в диалоге.
class AppDialogCancelButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const AppDialogCancelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}

// Основная кнопка диалога («Сохранить», «Удалить», «Завершить»…).
class AppDialogConfirmButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const AppDialogConfirmButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontSize: 13),
      ),
      child: Text(label),
    );
  }
}

// Оформление компактного поля ввода внутри диалога.
// Ошибку (errorText) показываем прямо под полем — SnackBar рисовался бы за фоном диалога.
InputDecoration appDialogInputDecoration({
  String? labelText,
  String? hintText,
  IconData? icon,
  Color iconColor = AppColors.accent,
  String? errorText,
}) {
  return InputDecoration(
    filled: true,
    fillColor: AppColors.inputFill,
    labelText: labelText,
    labelStyle: const TextStyle(color: AppColors.accent, fontSize: 12),
    hintText: hintText,
    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
    errorText: errorText,
    prefixIcon: icon != null ? Icon(icon, color: iconColor, size: 16) : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );
}
