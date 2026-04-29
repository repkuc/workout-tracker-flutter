import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/workout_service.dart';
import '../services/body_weight_service.dart';
import '../services/backup_service.dart';
import '../models/workout_models.dart';
import '../models/body_weight_entry.dart';
import 'workout_editor_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = WorkoutService();
  final _bodyWeightService = BodyWeightService();

  List<Workout> _completedWorkouts = [];
  Workout? _currentWorkout;
  BodyWeightEntry? _todayWeight;
  bool _isLoading = true;

  // Текущий месяц на календаре
  DateTime _calendarMonth = DateTime.now();

  final _newWorkoutNameController = TextEditingController();

  // Цвета для тренировок — такие же как в графике объёма
  final List<Color> _workoutColors = [
    const Color(0xFFF97316), // оранжевый
    const Color(0xFF34D399), // зелёный
    const Color(0xFF60A5FA), // голубой
    const Color(0xFFF472B6), // розовый
    const Color(0xFFA78BFA), // фиолетовый
    const Color(0xFFFBBF24), // жёлтый
  ];

// Map: название тренировки → цвет
  Map<String, Color> _nameColors = {};

// Map: дата → тренировка (для быстрого поиска)
  Map<String, Workout> _workoutByDate = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _newWorkoutNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final workouts = await _service.getCompletedWorkouts();
    final draft = await _service.getDraftWorkout();
    final todayWeight = await _bodyWeightService.getTodayEntry();
    // Назначаем цвета уникальным названиям тренировок
    // Назначаем цвета уникальным названиям тренировок
    final Map<String, Color> nameColors = {};
    int colorIndex = 0;
    for (final w in workouts) {
      if (!nameColors.containsKey(w.name)) {
        nameColors[w.name] = _workoutColors[colorIndex % _workoutColors.length];
        colorIndex++;
      }
    }

// Map дата → тренировка
    final Map<String, Workout> workoutByDate = {};
    for (final w in workouts) {
      workoutByDate[w.date] = w;
    }

    setState(() {
      _completedWorkouts = workouts;
      _currentWorkout = draft;
      _todayWeight = todayWeight;
      _nameColors = nameColors; // ← добавь
      _workoutByDate = workoutByDate; // ← добавь
      _isLoading = false;
    });
  }

  // Дни в которых были тренировки
  Set<String> get _workoutDays => _completedWorkouts.map((w) => w.date).toSet();

  // Общий объём за всё время
  double get _totalVolume => _completedWorkouts.fold(
      0,
      (sum, w) =>
          sum +
          w.exercises.fold(
              0,
              (s, e) =>
                  s + e.sets.fold(0, (ss, set) => ss + set.weight * set.reps)));

  // Общее время за всё время (секунды)
  int get _totalDuration =>
      _completedWorkouts.fold(0, (sum, w) => sum + (w.duration ?? 0));

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0)
      return '${hours}${'workout.hours_short'.tr()} ${minutes}${'workout.minutes_short'.tr()}';
    return '${minutes}${'workout.minutes_short'.tr()}';
  }

  String _formatVolume(double kg) {
    if (kg >= 1000)
      return '${(kg / 1000).toStringAsFixed(1)}${'workout.t'.tr()}';
    return '${kg.toStringAsFixed(0)}${'workout.kg'.tr()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFF97316)))
            : Column(
                children: [
                  // Шапка — фиксированная
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _buildHeader(),
                  ),

                  // Виджет веса — фиксированный
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildWeightWidget(),
                  ),

                  const SizedBox(height: 10),

                  // Календарь — занимает всё доступное место
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildCalendar(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Карточки статистики — фиксированная высота
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: IntrinsicHeight(
                      child: _buildStatsRow(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Кнопка — фиксированная
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _buildStartButton(),
                  ),
                ],
              ),
      ),
    );
  }

  // Шапка с названием и меню
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fitness_center,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              'home.title'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showAddWeightDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF97316), width: 2),
        ),
        titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text(
          'progress.add_weight_title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                labelText: 'progress.weight_kg'.tr(),
                labelStyle: const TextStyle(
                  color: Color(0xFFF97316),
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.monitor_weight,
                  color: Color(0xFFF97316),
                  size: 18,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final weight = double.tryParse(controller.text.trim());
              if (weight == null || weight <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('progress.weight_invalid'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, weight);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: Text('progress.save_weight'.tr()),
          ),
        ],
      ),
    );

    // Если пользователь ввёл вес — сохраняем
    if (result != null) {
      await _bodyWeightService.saveEntry(result);
      // Перезагружаем данные чтобы график обновился
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('progress.weight_saved'.tr()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  // Виджет веса тела
  Widget _buildWeightWidget() {
    return GestureDetector(
      onTap: () async {
        await _showAddWeightDialog();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _todayWeight != null
                ? const Color(0xFFE879F9).withOpacity(0.4)
                : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE879F9).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.monitor_weight,
                  color: Color(0xFFE879F9), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'progress.weight_title'.tr(),
                    style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        letterSpacing: 1),
                  ),
                  Text(
                    _todayWeight != null
                        ? '${_todayWeight!.weight} ${'workout.kg'.tr()}'
                        : 'progress.no_weight_today'.tr(),
                    style: TextStyle(
                      color: _todayWeight != null
                          ? Colors.white
                          : const Color(0xFF64748B),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _todayWeight != null
                  ? 'progress.edit_weight'.tr()
                  : 'progress.add_weight_short'.tr(),
              style: const TextStyle(color: Color(0xFFE879F9), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // Календарь с днями тренировок
  Widget _buildCalendar() {
    final now = DateTime.now();
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    int startWeekday = firstDay.weekday - 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Заголовок месяца
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: Colors.white, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() {
                  _calendarMonth =
                      DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                }),
              ),
              Text(
                DateFormat('MMMM yyyy', context.locale.languageCode)
                    .format(_calendarMonth),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: Colors.white, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() {
                  _calendarMonth =
                      DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                }),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Дни недели
          Row(
            children: [
              'calendar.mon'.tr(),
              'calendar.tue'.tr(),
              'calendar.wed'.tr(),
              'calendar.thu'.tr(),
              'calendar.fri'.tr(),
              'calendar.sat'.tr(),
              'calendar.sun'.tr(),
            ]
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(day,
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 10)),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),

          // Дни месяца — занимают всё оставшееся место
          Expanded(
            child: GridView.builder(
              shrinkWrap: false,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.1,
              ),
              itemCount: startWeekday + lastDay.day,
              itemBuilder: (context, index) {
                if (index < startWeekday) return const SizedBox();

                final day = index - startWeekday + 1;
                final date =
                    DateTime(_calendarMonth.year, _calendarMonth.month, day);
                final dateStr = '${date.year}-'
                    '${date.month.toString().padLeft(2, '0')}-'
                    '${day.toString().padLeft(2, '0')}';

                final isToday = date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;

                final workout = _workoutByDate[dateStr];
                final hasWorkout = workout != null;
                final workoutColor = hasWorkout
                    ? (_nameColors[workout.name] ?? const Color(0xFFF97316))
                    : null;

                return GestureDetector(
                  onTap:
                      hasWorkout ? () => _showWorkoutDaySheet(workout) : null,
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFFF97316)
                          : hasWorkout
                              ? workoutColor!.withOpacity(0.15)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: hasWorkout && !isToday
                          ? Border.all(color: workoutColor!, width: 1)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            color: isToday
                                ? Colors.white
                                : hasWorkout
                                    ? workoutColor
                                    : Colors.white,
                            fontSize: 11,
                            fontWeight: hasWorkout || isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (hasWorkout && !isToday)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: workoutColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 3 карточки статистики
  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard(
          icon: Icons.fitness_center,
          color: const Color(0xFFF97316),
          value: '${_completedWorkouts.length}',
          label: 'home.total_workouts'.tr(),
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          icon: Icons.monitor_weight,
          color: const Color(0xFF34D399),
          value: _formatVolume(_totalVolume),
          label: 'workout.total_volume_short'.tr(),
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          icon: Icons.timer,
          color: const Color(0xFF818CF8),
          value: _totalDuration > 0 ? _formatDuration(_totalDuration) : '—',
          label: 'workout.duration'.tr(),
        ),
      ],
    );
  }

  // Карточка статистики
  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1, // ← всегда квадратные!
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FittedBox — уменьшает текст автоматически
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  Text(
                    label,
                    style:
                        const TextStyle(color: Color(0xFF64748B), fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Кнопка начать тренировку
  Widget _buildStartButton() {
    final hasDraft = _currentWorkout != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          if (hasDraft) {
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WorkoutEditorPage(workoutId: _currentWorkout!.id),
                ),
              ).then((_) => _loadData());
            }
          } else {
            final name = await _showCreateWorkoutDialog();
            if (name == null) return;
            final workout = await _service.createWorkout(
              date: _service.getTodayDate(),
              name: name,
            );
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WorkoutEditorPage(workoutId: workout.id),
                ),
              ).then((_) => _loadData());
            }
          }
        },
        icon: Icon(hasDraft ? Icons.play_arrow : Icons.add_circle, size: 22),
        label: Text(
          (hasDraft ? 'workout.continue_workout' : 'home.start_workout')
              .tr()
              .toUpperCase(),
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              hasDraft ? const Color(0xFFF97316) : const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  // Диалог создания новой тренировки
  Future<String?> _showCreateWorkoutDialog() async {
    _newWorkoutNameController.text = 'workout.new_workout'.tr();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF97316), width: 2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withOpacity(0.2),
                  shape: BoxShape.circle),
              child: const Icon(Icons.add_circle,
                  color: Color(0xFFF97316), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text('workout.create_workout_dialog_title'.tr(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('workout.create_workout_message'.tr(),
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: _newWorkoutNameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                hintText: 'workout.workout_name_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon:
                    const Icon(Icons.fitness_center, color: Color(0xFFF97316)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('workout.cancel'.tr(),
                style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _newWorkoutNameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('workout.workout_name_required'.tr()),
                      backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(context, name);
            },
            child: Text('workout.create'.tr()),
          ),
        ],
      ),
    );
  }

  // Лист с деталями тренировки при нажатии на день в календаре
  void _showWorkoutDaySheet(Workout workout) {
    final color = _nameColors[workout.name] ?? const Color(0xFFF97316);

    // Считаем статистику
    final totalSets =
        workout.exercises.fold<int>(0, (sum, e) => sum + e.sets.length);
    final totalVolume = workout.exercises.fold<double>(
        0,
        (sum, e) =>
            sum + e.sets.fold(0, (s, set) => s + set.weight * set.reps));

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      workout.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                workout.date,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Статистика
              Row(
                children: [
                  _buildSheetStat(
                      Icons.fitness_center,
                      '${workout.exercises.length}',
                      'history.exercises'.tr(),
                      color),
                  const SizedBox(width: 10),
                  _buildSheetStat(
                      Icons.repeat, '$totalSets', 'history.sets'.tr(), color),
                  const SizedBox(width: 10),
                  _buildSheetStat(
                      Icons.monitor_weight,
                      _formatVolume(totalVolume),
                      'workout.total_volume_short'.tr(),
                      color),
                  if (workout.duration != null) ...[
                    const SizedBox(width: 10),
                    _buildSheetStat(
                        Icons.timer,
                        _formatDuration(workout.duration!),
                        'workout.duration'.tr(),
                        color),
                  ],
                ],
              ),

              const SizedBox(height: 20),

              // Кнопка повторить
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _repeatWorkout(workout.id);
                  },
                  icon: const Icon(Icons.repeat, size: 18),
                  label: Text('workout.repeat_workout'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetStat(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _repeatWorkout(String workoutId) async {
    try {
      final newWorkout = await _service.copyWorkout(workoutId);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutEditorPage(workoutId: newWorkout.id),
          ),
        ).then((_) => _loadData());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
