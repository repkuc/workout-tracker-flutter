import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/workout_service.dart';
import '../theme/app_colors.dart';
import 'chart_helpers.dart';
import 'tab_visibility.dart';

// Один столбик = одна завершённая тренировка (её цветом, по дате).
// В видимое окно графика помещается не больше ОДНОГО ГОДА: 7д / 30д / Год и
// «Все» с историей до года — всё на одном экране, ширина столбика — от ширины
// и числа столбиков. «Все» дольше года — в окне последние 12 месяцев (тот же
// размер столбиков, что у «Года»), более старые прокручиваются влево; только
// тогда снизу полоса прокрутки. Открывается на самых новых справа.
const int kVolumeWindowDays = 365;

// Ширина столбика: ячейка (ширина окна / столбиков в окне) × 1 — соседние
// касаются и сливаются в сплошную «лесенку»; при широкой ячейке (короткие
// периоды, мало тренировок) — 75 % ячейки, чтобы был виден зазор.
// Не тоньше kVolumeMinBarWidth (тогда столбики перекрываются, новые — сверху)
// и не шире kVolumeMaxBarWidth.
const double kVolumeMinBarWidth = 3;
const double kVolumeMaxBarWidth = 10;
const double kVolumeGapFromSlot = 8; // ячейка от 8 dp — с зазором

const double _plotHeight = 128;
const double _labelsHeight = 18;

class VolumeChartCard extends StatefulWidget {
  final int? selectedDays;

  const VolumeChartCard({
    super.key,
    required this.selectedDays,
  });

  @override
  State<VolumeChartCard> createState() => _VolumeChartCardState();
}

class _VolumeChartCardState extends State<VolumeChartCard>
    with ReloadWhenVisible {
  final _workoutService = WorkoutService();

  // Список записей: [{date, volume, name}, ...]
  List<Map<String, dynamic>> _data = [];
  double _totalVolume = 0;
  bool _isLoading = true;

  // Горизонтальная прокрутка столбиков; после загрузки — к самым новым
  final _scroll = ScrollController();
  bool _scrollToEnd = true;

  // Столбик под пальцем (подсказка рисуется своей, поверх окна графика,
  // чтобы у краёв её не обрезала прокрутка)
  int? _touchedIndex;

  // Цвета для разных тренировок
  final List<Color> _colors = [
    const Color(0xFFF97316), // оранжевый
    const Color(0xFF34D399), // зелёный
    const Color(0xFF60A5FA), // голубой
    const Color(0xFFF472B6), // розовый
    const Color(0xFFA78BFA), // фиолетовый
    const Color(0xFFFBBF24), // жёлтый
  ];

  // Уникальные названия тренировок → цвет
  Map<String, Color> _nameColors = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    // Данные тренировок изменились (например, в «Моих упражнениях») — перечитываем
    _workoutService.dataChanged.addListener(onWorkoutDataChanged);
  }

  @override
  void dispose() {
    _workoutService.dataChanged.removeListener(onWorkoutDataChanged);
    _scroll.dispose();
    super.dispose();
  }

  // Изменение данных: видимая вкладка перечитывает сразу, скрытая — при показе
  @override
  void reloadVisibleData() => _loadData(showSpinner: false);

  @override
  void didUpdateWidget(VolumeChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDays != widget.selectedDays) {
      _loadData();
    }
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);

    final data = await _workoutService.getVolumeByDateWithName(
      days: widget.selectedDays,
    );

    // Назначаем цвет каждому уникальному названию тренировки
    final Map<String, Color> nameColors = {};
    int colorIndex = 0;
    for (final item in data) {
      final name = item['name'] as String;
      if (!nameColors.containsKey(name)) {
        final colorStr = item['color'] as String?;
        if (colorStr != null && colorStr.isNotEmpty) {
          nameColors[name] = Color(int.parse('0xFF${colorStr.substring(1)}'));
        } else {
          nameColors[name] = _colors[colorIndex % _colors.length];
          colorIndex++;
        }
      }
    }

    final total = data.fold<double>(
      0,
      (sum, item) => sum + (item['volume'] as double),
    );

    if (!mounted) return;
    setState(() {
      _data = data;
      _totalVolume = total;
      _nameColors = nameColors;
      _isLoading = false;
      _scrollToEnd = true; // новые данные — снова к самым новым тренировкам
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.chartCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок + суммарный объём
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'progress.volume_title'.tr(),
                    style: const TextStyle(
                      color: AppColors.chartText,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLoading
                        ? '...'
                        : '${(_totalVolume / 1000).toStringAsFixed(1)}${'workout.t'.tr()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Легенда — названия тренировок с цветами
          if (!_isLoading && _nameColors.isNotEmpty)
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: _nameColors.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: entry.value,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.35,
                      ),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          color: AppColors.chartText,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),

          const SizedBox(height: 12),

          // График
          if (_isLoading)
            const SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (_data.isEmpty)
            SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  'progress.no_data'.tr(),
                  style: const TextStyle(color: AppColors.chartTextMuted),
                ),
              ),
            )
          else
            _buildChart(),
        ],
      ),
    );
  }

  // Подсказка: дата, название тренировки (её цветом), объём —
  // тёмная карточка в стиле подсказок остальных графиков
  Widget _tooltip(int index) {
    final item = _data[index];
    final name = item['name'] as String;
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceInset,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.chartGridMajor),
      ),
      child: Text.rich(
        TextSpan(
          text: '${chartTooltipDate(chartParseDate(item['date'] as String))}\n',
          style: kChartTooltipTitleStyle,
          children: [
            TextSpan(
              text: '$name\n',
              style: TextStyle(
                color: _nameColors[name] ?? AppColors.accent,
                fontSize: 11,
              ),
            ),
            TextSpan(
              text:
                  '${((item['volume'] as double) / 1000).toStringAsFixed(1)}${'workout.t'.tr()}',
              style: chartTooltipValueStyle(AppColors.volume),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final t = 'workout.t'.tr();
    final maxVolume = _data
        .map((e) => e['volume'] as double)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final scale = ChartScale.nice(0, maxVolume, fromZero: true);
    final leftWidth = scale.leftWidth(context, t, divisor: 1000);

    // Сколько последних столбиков помещается в окно (не больше года по датам):
    // история до года — все; дольше — тренировки последних 12 месяцев
    final n = _data.length;
    final lastDate = chartParseDate(_data.last['date'] as String);
    final windowStart = lastDate.subtract(const Duration(days: kVolumeWindowDays));
    final inWindow = _data
        .where((e) => !chartParseDate(e['date'] as String).isBefore(windowStart))
        .length;

    return LayoutBuilder(builder: (context, constraints) {
      final viewport = constraints.maxWidth - leftWidth;
      final scrollable = inWindow < n;
      final slot = viewport / inWindow;
      final content = slot * n;
      // Ширина столбика — см. kVolumeMinBarWidth: вплотную, с зазором 25 %
      // только при широкой ячейке
      final barWidth = (slot >= kVolumeGapFromSlot ? slot * 0.75 : slot)
          .clamp(kVolumeMinBarWidth, kVolumeMaxBarWidth)
          .toDouble();

      if (_scrollToEnd) {
        _scrollToEnd = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }

      return Column(
        children: [
          SizedBox(
            height: _plotHeight,
            child: Row(
              children: [
                // Подписи Y не прокручиваются
                ChartYAxisColumn(
                    scale: scale, unit: t, divisor: 1000, height: _plotHeight),
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: SingleChildScrollView(
                          controller: _scroll,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: SizedBox(
                            width: content,
                            height: _plotHeight,
                            child: _buildBars(scale, slot, barWidth),
                          ),
                        ),
                      ),
                      // Подсказка поверх окна: над столбиком, внутри видимой части
                      if (_touchedIndex != null && _touchedIndex! < n)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _scroll,
                              builder: (context, _) {
                                final i = _touchedIndex!;
                                final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                                return CustomSingleChildLayout(
                                  delegate: _TooltipLayout(
                                    barX: slot * (i + 0.5) - offset,
                                    barTop: _plotHeight *
                                        (1 -
                                            scale.toChart(_data[i]['volume'] as double) /
                                                scale.maxY),
                                  ),
                                  child: _tooltip(i),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Подписи дат — по видимой части (первый и последний видимый столбик)
          Padding(
            padding: EdgeInsets.only(left: leftWidth),
            child: SizedBox(
              height: _labelsHeight,
              child: AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) =>
                    _buildDateLabels(viewport: viewport, slot: slot),
              ),
            ),
          ),
          // Полоса прокрутки — только если история дольше года (окно не вмещает всё)
          if (scrollable)
            Padding(
              padding: EdgeInsets.only(left: leftWidth),
              child: _ChartScrollbar(
                  controller: _scroll, viewport: viewport, content: content),
            ),
        ],
      );
    });
  }

  Widget _buildBars(ChartScale scale, double slot, double barWidth) {
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: scale.maxY,
        // Центры столбиков — ровно посередине своей ячейки (slot × (i + 0.5)),
        // по ним же стоят подписи дат и подсказка
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: scale.grid(),
        titlesData: const FlTitlesData(show: false),
        barTouchData: BarTouchData(
          // Своя подсказка (не встроенная). Столбик выбираем сами — по ячейке
          // под пальцем (x / slot), на любой высоте: это ближайший столбик,
          // даже когда столбики шире ячейки и перекрываются (fl_chart выбрал
          // бы первый, т. е. более старый, нижний).
          handleBuiltInTouches: false,
          touchCallback: (event, response) {
            final x = event.localPosition?.dx;
            final index = event.isInterestedForInteractions && x != null
                ? (x / slot).floor().clamp(0, _data.length - 1)
                : null;
            if (index != _touchedIndex) setState(() => _touchedIndex = index);
          },
        ),
        barGroups: [
          for (var i = 0; i < _data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: scale.toChart(_data[i]['volume'] as double),
                  // Выбранный столбик — светлее, видно, о каком подсказка
                  color: i == _touchedIndex
                      ? Color.lerp(_nameColors[_data[i]['name']] ?? AppColors.accent,
                          Colors.white, 0.35)
                      : _nameColors[_data[i]['name']] ?? AppColors.accent,
                  width: barWidth,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(barWidth / 2),
                    topRight: Radius.circular(barWidth / 2),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Подписи дат под видимыми столбиками: всегда первый и последний видимый,
  // между ними равномерно (до 4), без наложения; формат — по видимому диапазону.
  Widget _buildDateLabels({required double viewport, required double slot}) {
    final n = _data.length;
    final offset = _scroll.hasClients && _scroll.position.hasContentDimensions
        ? _scroll.offset
        : 0.0;
    final first =
        ((offset / slot - 0.5).ceil()).clamp(0, n - 1); // первый видимый
    final last =
        (((offset + viewport) / slot - 0.5).floor()).clamp(first, n - 1);
    final lang = context.locale.languageCode;
    final style = chartDateStyleFor(chartParseDate(_data[first]['date']),
        chartParseDate(_data[last]['date']));

    // Подписи для count штук: индекс, текст, левый край, ширина
    List<(int, String, double, double)> layout(int count) {
      final indices = <int>{
        for (var i = 0; i < count; i++)
          count == 1
              ? last
              : first + ((last - first) * i / (count - 1)).round(),
      }.toList();
      return [
        for (final i in indices)
          () {
            final text = chartAxisDate(
                chartParseDate(_data[i]['date'] as String), style, lang);
            final w = chartTextWidth(context, text);
            final x = slot * (i + 0.5) - offset;
            return (
              i,
              text,
              (x - w / 2).clamp(0.0, math.max(0.0, viewport - w)).toDouble(),
              w
            );
          }(),
      ];
    }

    bool fits(List<(int, String, double, double)> labels) {
      for (var j = 1; j < labels.length; j++) {
        if (labels[j].$3 < labels[j - 1].$3 + labels[j - 1].$4 + 6) return false;
      }
      return true;
    }

    var labels = layout(1);
    for (var k = math.min(4, last - first + 1); k >= 2; k--) {
      final candidate = layout(k);
      if (fits(candidate) || k == 2) {
        labels = fits(candidate) ? candidate : layout(1);
        break;
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final l in labels)
          Positioned(
            left: l.$3,
            top: 4,
            child: Text(l.$2,
                style: kChartAxisStyle, maxLines: 1, softWrap: false),
          ),
      ],
    );
  }
}

// Полоса прокрутки под графиком: тонкая дорожка и ползунок; ползунок можно
// тянуть, нажатие на дорожку переносит к этому месту.
class _ChartScrollbar extends StatelessWidget {
  final ScrollController controller;
  final double viewport;
  final double content;

  const _ChartScrollbar({
    required this.controller,
    required this.viewport,
    required this.content,
  });

  double get _thumbWidth =>
      math.max(24.0, viewport * viewport / content).clamp(0.0, viewport);

  double get _maxOffset => math.max(0.0, content - viewport);

  void _jumpTo(double offset) {
    if (!controller.hasClients) return;
    controller.jumpTo(offset.clamp(0.0, _maxOffset));
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumbWidth;
    final travel = math.max(1.0, viewport - thumb);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => _jumpTo(
          (controller.hasClients ? controller.offset : 0) +
              d.delta.dx * _maxOffset / travel),
      onTapDown: (d) =>
          _jumpTo((d.localPosition.dx - thumb / 2) / travel * _maxOffset),
      child: SizedBox(
        height: 20,
        width: viewport,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final offset = controller.hasClients &&
                    controller.position.hasContentDimensions
                ? controller.offset
                : _maxOffset;
            final left = _maxOffset == 0 ? 0.0 : offset / _maxOffset * travel;
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.chartScrollTrack,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Positioned(
                  left: left,
                  child: Container(
                    key: const ValueKey('volume-scroll-thumb'),
                    width: thumb,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.chartScrollThumb,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Положение подсказки: по центру над столбиком (barX — центр столбика в окне,
// barTop — верх столбика), но целиком внутри окна графика по горизонтали;
// если над столбиком мало места — вплотную к верху.
class _TooltipLayout extends SingleChildLayoutDelegate {
  final double barX;
  final double barTop;

  _TooltipLayout({required this.barX, required this.barTop});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = (barX - child.width / 2)
        .clamp(0.0, math.max(0.0, size.width - child.width))
        .toDouble();
    final y = math.max(0.0, barTop - child.height - 6);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_TooltipLayout old) =>
      old.barX != barX || old.barTop != barTop;
}
