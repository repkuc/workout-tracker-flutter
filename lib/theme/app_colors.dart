import 'package:flutter/material.dart';

// Общие цвета интерфейса приложения.
// Цвета названы по СМЫСЛУ, а не по оттенку: если у двух ролей сейчас один и тот же
// hex, это всё равно разные константы — чтобы одну можно было поменять, не задев другую.
// Палитра цветов тренировок, которую выбирает пользователь (сохраняется в данных),
// и списки цветов серий графиков сюда намеренно НЕ вынесены.
abstract final class AppColors {
  // ── Фон и поверхности ──
  static const Color background = Color(0xFF0F172A); // фон экранов, нижняя навигация, нижние панели
  static const Color surface = Color(0xFF1E293B); // карточки, диалоги, bottom sheet, невыбранные чипы
  static const Color surfaceInset = Color(0xFF0F172A); // вложенные блоки и чипы внутри карточек/диалогов
  // Поле ввода должно отличаться от того, на чём лежит:
  // внутри диалогов/карточек (фон surface) — inputFill,
  // прямо на фоне экрана (background) — inputFillOnPage.
  static const Color inputFill = Color(0xFF0F172A); // заливка полей в диалогах и карточках
  static const Color inputFillOnPage = Color(0xFF1E293B); // заливка полей прямо на фоне экрана
  static const Color divider = Color(0xFF0F172A); // разделители внутри карточек
  static const Color chipBorder = Color(0xFF374151); // рамка невыбранного чипа

  // ── Акцент ──
  static const Color accent = Color(0xFFF97316); // основной оранжевый: кнопки, иконки, выбранное состояние
  static const Color dialogBorder = Color(0xFFF97316); // рамка диалогов

  // ── Текст ──
  static const Color textMuted = Color(0xFF64748B); // второстепенный текст и иконки
  static const Color textSoft = Color(0xFFE2E8F0); // светлый текст строк в списках статистики

  // ── Статусы ──
  static const Color success = Color(0xFF10B981); // успех / выполнено
  static const Color pending = Color(0xFFF97316); // ещё не выполнено (подход, упражнение)
  static const Color setRowPending = Color(0xFF4B5563); // фон невыполненного подхода (с прозрачностью)
  static const Color draft = Color(0xFFF97316); // черновик тренировки, «Продолжить»
  static const Color active = Color(0xFF10B981); // идущая тренировка: живой таймер, баннер, кнопки старт/продолжить
  static const Color paused = Color(0xFFF97316); // таймер на паузе
  static const Color warning = Color(0xFFF97316); // предупреждение (незавершённые упражнения)
  static const Color improvement = Color(0xFF10B981); // положительная разница «до / после»
  static const Color record = Color(0xFFFBBF24); // рекорды (PR): значок в редакторе, список в статистике
  static const Color danger = Color(0xFFEF4444); // удаление, ошибки, отрицательная разница (Tailwind red-500)

  // ── Нейтральные серые (slate) ──
  static const Color inactive = Color(0xFF94A3B8); // невыбранные иконки навигации, неактивные/невыполненные элементы
  static const Color iconNeutral = Color(0xFF94A3B8); // нейтральная иконка целевой мышцы
  static const Color completedButton = Color(0xFF475569); // кнопка уже завершённого упражнения
  static const Color snackbarNeutral = Color(0xFF475569); // нейтральный snackbar: «удалено», «нечего импортировать» (цвет по умолчанию)
  static const Color sheetHandle = Color(0xFF475569); // «ручка» сверху нижнего меню (bottom sheet)

  // ── Метрики (карточки статистики) ──
  static const Color count = Color(0xFFF97316); // количество тренировок / упражнений
  static const Color volume = Color(0xFF22D3EE); // объём (кг): карточки, топ упражнений, сравнение в редакторе
  static const Color reps = Color(0xFF818CF8); // повторения
  static const Color duration = Color(0xFF60A5FA); // время

  // ── Разделы и фичи ──
  static const Color program = Color(0xFF818CF8); // бейдж программы, «последний раз»
  static const Color restTimer = Color(0xFF818CF8); // таймер отдыха и его чипы
  static const Color bodyWeight = Color(0xFFE879F9); // вес тела: быстрый ввод, график

  // ── Иконки настроек ──
  static const Color iconExport = Color(0xFF10B981);
  static const Color iconImport = Color(0xFF60A5FA);
  static const Color iconInfo = Color(0xFF818CF8);

  // ── Медали топа упражнений ──
  static const Color medalGold = Color(0xFFFFD700);
  static const Color medalSilver = Color(0xFFC0C0C0);
  static const Color medalBronze = Color(0xFFCD7F32);
  static const Color medalNone = Color(0xFF374151);

  // ── Изменение веса тела ──
  static const Color weightDownText = Color(0xFF34D399); // похудел — светлый текст на тёмно-зелёном
  static const Color weightDownBackground = Color(0xFF064E3B);
  static const Color weightUpText = Color(0xFFFB7185);
  static const Color weightUpBackground = Color(0xFF7C2D12);

  // ── Карточки графиков ──
  static const Color chartCard = surface; // фон карточки графика
  static const Color chartText = Color(0xFF94A3B8); // заголовки и легенда
  static const Color chartTextMuted = textMuted; // подписи осей, «нет данных»
  static const Color chartGrid = Color(0xFF334155); // обычные линии сетки
  static const Color chartGridMajor = Color(0xFF475569); // «главные» линии: целые кг (вес), каждые 5 т (объём)
  static const Color chartPill = Color(0xFF334155); // кнопка «показать ещё / свернуть» под чипами упражнений

  // ── Material-темы (main.dart) ──
  static const Color themeDarkPrimary = Color(0xFFFB923C);
  static const Color themeDarkSurface = Color(0xFF111827);
  static const Color themeDarkCard = Color(0xFF1F2937);
}
