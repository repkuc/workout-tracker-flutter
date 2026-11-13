import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'workout_service.dart';

// Обёртка над In-App Review: в тестах подменяется заглушкой
class ReviewApi {
  const ReviewApi();

  Future<bool> isAvailable() => InAppReview.instance.isAvailable();
  Future<void> requestReview() => InAppReview.instance.requestReview();
  Future<void> openStoreListing() => InAppReview.instance.openStoreListing();
  Future<bool> launchStorePage(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}

// Просьба оценить приложение в Google Play (официальное окно In-App Review).
// После 4-й, 8-й и 16-й завершённой тренировки — каждый рубеж не больше одного
// раза, после 16-й больше никогда. По правилам Google Play: без вопроса
// «Нравится приложение?» перед окном, без наград и без фильтра по оценке.
class ReviewPromptService {
  static final ReviewPromptService _instance = ReviewPromptService._internal();
  factory ReviewPromptService() => _instance;
  ReviewPromptService._internal();

  static const List<int> milestones = [4, 8, 16];
  // Использованные рубежи (List<int> строками). Не входит в бэкап
  static const String usedKey = 'wt.review_prompts.v1';
  static final Uri storeUrl = Uri.parse(
      'https://play.google.com/store/apps/details?id=lv.repkuc.workoutdiary');

  ReviewApi api = const ReviewApi();
  // Пауза после закрытия редактора: не мешать snackbar «Тренировка завершена»
  Duration delay = const Duration(milliseconds: 1500);

  // Сколько редакторов тренировки сейчас открыто (initState / dispose редактора)
  int _openEditors = 0;
  void editorOpened() => _openEditors++;
  void editorClosed() => _openEditors--;

  List<int>? _loadUsed(SharedPreferences prefs) =>
      prefs.getStringList(usedKey)?.map(int.tryParse).whereType<int>().toList();

  Future<void> _saveUsed(SharedPreferences prefs, Iterable<int> used) =>
      prefs.setStringList(
          usedKey, (used.toSet().toList()..sort()).map((m) => '$m').toList());

  // Один раз при запуске (ключа ещё нет): рубежи, которые уже пройдены,
  // считаем использованными — обновившийся пользователь с 10 тренировками
  // получит просьбу на 16-й, с 16 и больше — никогда
  Future<void> seedIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(usedKey)) return;
      final done = await _doneCount();
      await _saveUsed(prefs, milestones.where((m) => m <= done));
    } catch (e) {
      debugPrint('Review prompt seed failed: $e');
    }
  }

  // Вызывается редактором сразу после успешного завершения тренировки (перед
  // закрытием). Сама просьба — через [delay], когда пользователь уже вне
  // редактора и нет идущей тренировки. Ошибки наружу не идут.
  Future<void> onWorkoutFinished() async {
    try {
      await Future<void>.delayed(delay);
      // Пользователь уже снова в редакторе (начал новую тренировку) —
      // не спрашиваем; рубеж остаётся неиспользованным до следующего завершения
      if (_openEditors > 0) return;
      if (await WorkoutService().getCurrentWorkoutId() != null) return;

      final prefs = await SharedPreferences.getInstance();
      final used = _loadUsed(prefs) ?? <int>[];
      final done = await _doneCount();
      final due = milestones.where((m) => m <= done && !used.contains(m));
      if (due.isEmpty) return;

      // Сначала отмечаем (все пройденные рубежи разом — одна просьба),
      // чтобы не спросить повторно даже при сбое окна
      await _saveUsed(prefs, [...used, ...milestones.where((m) => m <= done)]);
      if (!await api.isAvailable()) return;
      await api.requestReview();
    } catch (e) {
      debugPrint('Review prompt failed: $e');
    }
  }

  // Строка «Оценить приложение» в настройках: страница в Google Play,
  // при ошибке — та же страница по ссылке
  Future<void> openStoreListing() async {
    try {
      await api.openStoreListing();
    } catch (e) {
      debugPrint('openStoreListing failed: $e');
      try {
        await api.launchStorePage(storeUrl);
      } catch (e) {
        debugPrint('Store page launch failed: $e');
      }
    }
  }

  Future<int> _doneCount() async => (await WorkoutService().loadAllWorkouts())
      .where((w) => w.status == 'done')
      .length;
}
