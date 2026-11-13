import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// Общие правила всех графиков статистики (объём, прогресс упражнений,
// вес тела, замеры) — чтобы они выглядели и вели себя одинаково:
// - ось X: ~4 подписи дат, равномерно, ВСЕГДА с первой и последней датой;
//   до ~90 дней «dd.MM», дольше — короткий месяц (+ год, если диапазон
//   переходит через год); подписей меньше, если не помещаются;
// - ось Y: 4–5 «круглых» делений с единицей из переводов, без отдельной
//   подписи на максимуме (значения переводятся в шкалу 0…N, деление = 1);
// - касание: тёмная подсказка с датой и значениями;
// - точки: больше kChartDotLimit точек — только линия и одна точка на последней;
// - линии прямые (без кривых), чтобы не выходить за реальные значения.

// Больше точек в линии — рисуем только последнюю
const int kChartDotLimit = 20;

// Подписи осей
const TextStyle kChartAxisStyle =
    TextStyle(color: AppColors.chartTextMuted, fontSize: 10);

// Подсказка при касании: заголовок (дата / период) и строки значений
const TextStyle kChartTooltipTitleStyle = TextStyle(
    color: AppColors.chartText, fontSize: 11, fontWeight: FontWeight.w600);

TextStyle chartTooltipValueStyle(Color color) =>
    TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold);

// ─── Даты ────────────────────────────────────────────────────────────────

// 'YYYY-MM-DD' → дата (UTC, без сдвигов из-за часовых поясов)
DateTime chartParseDate(String ymd) {
  final p = ymd.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

// Номер дня (дни с 1970-01-01) — для оси X «по времени»
int chartDayOf(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

DateTime chartDateOfDay(int day) =>
    DateTime.fromMillisecondsSinceEpoch(day * Duration.millisecondsPerDay,
        isUtc: true);

// Формат подписей оси X — выбирается по длине показанного диапазона
enum ChartDateStyle { dayMonth, month, monthYear }

ChartDateStyle chartDateStyleFor(DateTime first, DateTime last) {
  if (last.difference(first).inDays <= 92) return ChartDateStyle.dayMonth;
  return first.year != last.year
      ? ChartDateStyle.monthYear
      : ChartDateStyle.month;
}

// Подпись даты на оси: «24.10», «мар», «мар 2025» (месяц — отдельная
// форма LLL, как в заголовке календаря)
String chartAxisDate(DateTime d, ChartDateStyle style, String lang) {
  switch (style) {
    case ChartDateStyle.dayMonth:
      return DateFormat('dd.MM').format(d);
    case ChartDateStyle.month:
      return DateFormat('LLL', lang).format(d);
    case ChartDateStyle.monthYear:
      return DateFormat('LLL yyyy', lang).format(d);
  }
}

// Дата в подсказке
String chartTooltipDate(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

// ─── Числа ───────────────────────────────────────────────────────────────

// 88.5 → «88.5», 90.0 → «90», 97.25 → «97.25» (не больше maxDecimals знаков)
String chartNumber(double v, {int maxDecimals = 2}) {
  var s = v.toStringAsFixed(maxDecimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s == '-0' ? '0' : s;
}

// Разница со знаком: «+12.5», «-4.5», «0»
String chartSignedNumber(double v) =>
    v > 0 ? '+${chartNumber(v)}' : chartNumber(v);

// Размер текста с учётом масштаба шрифта телефона
Size chartTextSize(BuildContext context, String text,
    [TextStyle style = kChartAxisStyle]) {
  final painter = TextPainter(
    // Тот же шрифт, что у Text в дереве (тема), а не шрифт движка по умолчанию
    text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.size;
}

double chartTextWidth(BuildContext context, String text,
        [TextStyle style = kChartAxisStyle]) =>
    chartTextSize(context, text, style).width;

// ─── Ось Y ───────────────────────────────────────────────────────────────

// «Круглая» шкала: деления lo, lo+step, … lo+ticks*step (4–5 подписей).
// На графике значения переводятся в 0…ticks (toChart), деление = 1 —
// так fl_chart не добавляет лишних подписей (например, на максимуме).
class ChartScale {
  final double lo;
  final double step;
  final int ticks;

  const ChartScale._(this.lo, this.step, this.ticks);

  // fromZero — шкала от нуля (объём); иначе — по диапазону значений (вес, замеры)
  factory ChartScale.nice(double min, double max, {bool fromZero = false}) {
    if (fromZero) min = math.min(0, min);
    if (max - min < 1e-9) {
      // Одно значение: немного места сверху и снизу
      final pad = max.abs() < 1e-9 ? 1.0 : math.max(max.abs() * 0.02, 0.5);
      max += pad;
      if (!fromZero) min -= pad;
    }
    const bases = [1.0, 2.0, 2.5, 5.0];
    final raw = (max - min) / 4;
    var exp = (math.log(raw) / math.ln10).floor() - 1;
    while (true) {
      final mag = math.pow(10, exp).toDouble();
      for (final b in bases) {
        final step = b * mag;
        final lo = (min / step + 1e-9).floor() * step;
        final hi = (max / step - 1e-9).ceil() * step;
        final ticks = ((hi - lo) / step).round();
        if (ticks <= 4) return ChartScale._(lo, step, math.max(ticks, 1));
      }
      exp++;
    }
  }

  double toChart(double v) => (v - lo) / step;
  double valueAt(int tick) => lo + tick * step;
  double get maxY => ticks.toDouble();

  // Сколько знаков после запятой нужно подписям (2.5 → 1, 0.25 → 2, 5 → 0)
  static int _decimalsOf(double step) {
    for (var d = 0; d < 4; d++) {
      final scaled = step * math.pow(10, d);
      if ((scaled - scaled.roundToDouble()).abs() < 1e-6) return d;
    }
    return 4;
  }

  // Подпись деления: «85кг», «2.5т» (единица — из переводов;
  // divisor — например 1000 для тонн при значениях в кг)
  String label(int tick, String unit, {double divisor = 1}) =>
      '${(valueAt(tick) / divisor).toStringAsFixed(_decimalsOf(step / divisor))}$unit';

  // Сетка — линия на каждом делении
  FlGridData grid() => FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: AppColors.chartGrid, strokeWidth: 0.8),
      );

  // Подписи слева: ширина — по самой длинной подписи
  // Ширина колонки подписей слева
  double leftWidth(BuildContext context, String unit, {double divisor = 1}) {
    var width = 0.0;
    for (var t = 0; t <= ticks; t++) {
      width = math.max(
          width, chartTextWidth(context, label(t, unit, divisor: divisor)));
    }
    return width + 6;
  }

  AxisTitles leftTitles(BuildContext context, String unit,
      {double divisor = 1}) {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: 1,
        reservedSize: leftWidth(context, unit, divisor: divisor),
        getTitlesWidget: (value, meta) {
          final tick = value.round();
          if ((value - tick).abs() > 1e-6 || tick < 0 || tick > ticks) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(
            axisSide: meta.axisSide,
            space: 4,
            fitInside: SideTitleFitInsideData.fromTitleMeta(meta,
                distanceFromEdge: 0),
            child: Text(label(tick, unit, divisor: divisor),
                style: kChartAxisStyle, maxLines: 1, softWrap: false),
          );
        },
      ),
    );
  }
}

// Неподвижная колонка подписей Y — для графика, который прокручивается
// по горизонтали (сам график рисуется без левых подписей). Деления стоят
// там же, где линии сетки графика высотой height; крайние подписи прижаты внутрь.
class ChartYAxisColumn extends StatelessWidget {
  final ChartScale scale;
  final String unit;
  final double divisor;
  final double height;

  const ChartYAxisColumn({
    super.key,
    required this.scale,
    required this.unit,
    required this.height,
    this.divisor = 1,
  });

  @override
  Widget build(BuildContext context) {
    final width = scale.leftWidth(context, unit, divisor: divisor);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          for (var t = 0; t <= scale.ticks; t++)
            () {
              final text = scale.label(t, unit, divisor: divisor);
              final h = chartTextSize(context, text).height;
              final y = height * (1 - t / scale.ticks);
              return Positioned(
                right: 4,
                top: (y - h / 2).clamp(0.0, math.max(0.0, height - h)),
                child: Text(text,
                    style: kChartAxisStyle, maxLines: 1, softWrap: false),
              );
            }(),
        ],
      ),
    );
  }
}

// ─── Ось X ───────────────────────────────────────────────────────────────

// Сколько подписей (2…4) помещается: соседние не налезают друг на друга,
// крайние прижаты к краям (поэтому для них нужно 1.5 ширины).
int chartFitLabelCount({
  required double plotWidth,
  required List<String> Function(int count) labelsFor,
  required double Function(String) measure,
  int maxCount = 4,
}) {
  for (var k = maxCount; k > 2; k--) {
    final widest = labelsFor(k).map(measure).fold<double>(0, math.max);
    if (plotWidth / (k - 1) >= widest * 1.5 + 8) return k;
  }
  return 2;
}

Widget _bottomLabel(TitleMeta meta, String text) => SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4,
      fitInside:
          SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
      child: Text(text, style: kChartAxisStyle, maxLines: 1, softWrap: false),
    );

// Ось X «по времени» для линейных графиков: X = доля диапазона дат,
// подписи стоят на целых значениях 0…count-1 (первая и последняя дата всегда).
class ChartTimeAxis {
  final int firstDay;
  final int lastDay;
  final int count; // число подписей
  final ChartDateStyle style;
  final String lang;

  const ChartTimeAxis._(
      this.firstDay, this.lastDay, this.count, this.style, this.lang);

  factory ChartTimeAxis.build(
    BuildContext context, {
    required int firstDay,
    required int lastDay,
    required double plotWidth,
  }) {
    final lang = context.locale.languageCode;
    final style =
        chartDateStyleFor(chartDateOfDay(firstDay), chartDateOfDay(lastDay));
    if (lastDay <= firstDay) {
      return ChartTimeAxis._(firstDay, firstDay, 1, style, lang);
    }
    final probe = ChartTimeAxis._(firstDay, lastDay, 4, style, lang);
    final count = chartFitLabelCount(
      plotWidth: plotWidth,
      labelsFor: (k) => [
        for (var i = 0; i < k; i++)
          chartAxisDate(probe._dayAt(i, k), style, lang)
      ],
      measure: (s) => chartTextWidth(context, s),
      // Диапазон в 1–2 дня — не больше подписей, чем дней (без повторов)
      maxCount: math.min(4, lastDay - firstDay + 1),
    );
    return ChartTimeAxis._(firstDay, lastDay, count, style, lang);
  }

  int get span => lastDay - firstDay;

  DateTime _dayAt(int i, int k) =>
      chartDateOfDay(firstDay + (span * i / (k - 1)).round());

  // X точки по её дню (одна дата → 0, по центру)
  double x(int day) => span == 0 ? 0 : (day - firstDay) * (count - 1) / span;

  // День ближайший к X (для подсказки)
  int dayAtX(double x) =>
      span == 0 ? firstDay : firstDay + (x * span / (count - 1)).round();

  double get minX => span == 0 ? -1 : 0;
  double get maxX => span == 0 ? 1 : (count - 1).toDouble();

  AxisTitles bottomTitles() => AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          reservedSize: 22,
          getTitlesWidget: (value, meta) {
            final i = value.round();
            if ((value - i).abs() > 1e-6) return const SizedBox.shrink();
            if (span == 0) {
              if (i != 0) return const SizedBox.shrink();
              return _bottomLabel(
                  meta, chartAxisDate(chartDateOfDay(firstDay), style, lang));
            }
            if (i < 0 || i >= count) return const SizedBox.shrink();
            return _bottomLabel(meta, chartAxisDate(_dayAt(i, count), style, lang));
          },
        ),
      );
}

// ─── Линии, точки, касание ───────────────────────────────────────────────

// Точки: до kChartDotLimit — все, больше — только последняя (крупнее, с обводкой)
FlDotData chartDots(Color color, int count) {
  if (count > kChartDotLimit) {
    return FlDotData(
      show: true,
      checkToShowDot: (spot, bar) => spot == bar.spots.last,
      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
        radius: 4,
        color: color,
        strokeWidth: 2,
        strokeColor: AppColors.chartCard,
      ),
    );
  }
  return FlDotData(
    show: true,
    getDotPainter: (spot, percent, bar, index) =>
        FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0),
  );
}

// Линия графика: прямые отрезки (не выходят за реальные значения)
LineChartBarData chartLine({
  required List<FlSpot> spots,
  required Color color,
  bool area = false,
}) =>
    LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 2,
      isCurved: false,
      dotData: chartDots(color, spots.length),
      belowBarData: area
          // ignore: deprecated_member_use
          ? BarAreaData(show: true, color: color.withOpacity(0.08))
          : BarAreaData(show: false),
    );

// Невидимая линия-«сетка дат» (прозрачная): точка на каждой дате графика,
// чтобы касание попадало на дату, а подсказка показывала все линии этой даты.
LineChartBarData chartDateGuideLine(List<double> xs, double y) =>
    LineChartBarData(
      spots: [for (final x in xs) FlSpot(x, y)],
      color: Colors.transparent,
      barWidth: 0,
      dotData: const FlDotData(show: false),
    );

bool _isGuide(LineChartBarData bar) => bar.color == Colors.transparent;

// Касание линейного графика: ближайшая по X точка (порог большой, чтобы
// подсказка появлялась при касании в любом месте), вертикальная линия-указатель.
// С линией-«сеткой дат» указатель — только у неё (у настоящих линий
// ближайшие точки могут быть на других датах).
LineTouchData chartLineTouch({
  required List<LineTooltipItem?> Function(List<LineBarSpot> spots) items,
  bool hasDateGuide = false,
}) =>
    LineTouchData(
      touchSpotThreshold: 100000,
      getTouchedSpotIndicator: (bar, indexes) => indexes.map((_) {
        final guide = _isGuide(bar);
        final line = hasDateGuide ? guide : true;
        return TouchedSpotIndicatorData(
          FlLine(
              color: line ? AppColors.chartGridMajor : Colors.transparent,
              strokeWidth: 1),
          FlDotData(
            show: !hasDateGuide && !guide,
            getDotPainter: (spot, percent, b, index) => FlDotCirclePainter(
              radius: 4,
              color: b.color ?? AppColors.accent,
              strokeWidth: 2,
              strokeColor: AppColors.chartCard,
            ),
          ),
        );
      }).toList(),
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => AppColors.surfaceInset,
        tooltipBorder: const BorderSide(color: AppColors.chartGridMajor),
        tooltipRoundedRadius: 8,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        maxContentWidth: 220,
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItems: items,
      ),
    );

// ─── Бейдж изменения ─────────────────────────────────────────────────────

// Бейдж «разница первой и последней записи» (вес тела, замеры):
// уменьшение — зелёный, увеличение — красный.
class ChartChangeBadge extends StatelessWidget {
  final double delta;
  final String unit;

  const ChartChangeBadge({super.key, required this.delta, required this.unit});

  @override
  Widget build(BuildContext context) {
    final isDown = delta < 0; // похудел = хорошо (зелёный)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDown
            ? AppColors.weightDownBackground
            : AppColors.weightUpBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${isDown ? '' : '+'}${delta.toStringAsFixed(1)} $unit',
        style: TextStyle(
          color: isDown ? AppColors.weightDownText : AppColors.weightUpText,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
