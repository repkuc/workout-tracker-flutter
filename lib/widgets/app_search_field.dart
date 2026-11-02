import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_colors.dart';

// Поле поиска прямо на фоне экрана (выбор упражнения, библиотека):
// лупа слева, × справа, пока есть текст.
class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.inputFillOnPage,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              hintText: hintText,
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textMuted, size: 20),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.textMuted, size: 20),
                      tooltip: 'exercise_library.clear_search'.tr(),
                      onPressed: controller.clear,
                    ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}
