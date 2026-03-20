import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'services/workout_service.dart';
import 'pages/workout_editor_page.dart';
import 'pages/history_page.dart';
import 'models/workout_models.dart';
import 'pages/statistics_page.dart';
import 'pages/progress_page.dart';
import 'services/backup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Инициализируем сервис работы с тренировками
  final workoutService = WorkoutService();
  await workoutService.init();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('ru'),
        Locale('lv'),
        Locale('en'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'app_name'.tr(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // СВЕТЛАЯ ТЕМА - Энергичная (красный + оранжевый)
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFF97316), // ОРАНЖЕВЫЙ (энергия)
          secondary: Color(0xFFEA580C), // Тёмно-оранжевый
          tertiary: Color(0xFF10B981), // Зелёный (успех)
          surface: Color(0xFFF5F5F5), // Светло-серый
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F2937), // Тёмно-серый (металл)
          foregroundColor: Colors.white,
          elevation: 4,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFB923C), // Оранжевый
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
          ),
        ),
      ),

      // ТЁМНАЯ ТЕМА - Брутальная (чёрный + красный)
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFB923C), // Ярко-оранжевый
          secondary: Color(0xFFF97316), // Оранжевый
          tertiary: Color(0xFF34D399), // Зелёный
          surface: Color(0xFF111827), // Почти чёрный
          onPrimary: Colors.white,
          onSecondary: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A), // Глубокий чёрный
          foregroundColor: Colors.white,
          elevation: 4,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: const Color(0xFF1F2937), // Тёмно-серый
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF97316), // Оранжевый
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
      ),

      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = WorkoutService();
  int _workoutCount = 0;
  bool _isLoading = true;
  int _draftCount = 0;
  Workout? _currentWorkout;

// Контроллер для названия новой тренировки
  final _newWorkoutNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWorkoutCount();
  }

  Future<void> _loadWorkoutCount() async {
    final workouts = await _service.getCompletedWorkouts();
    final draft = await _service.getDraftWorkout();
    setState(() {
      _workoutCount = workouts.length;
      _draftCount = draft != null ? 1 : 0;
      _currentWorkout = draft;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Брутальный градиент (чёрный → тёмно-серый)
      body: Container(
        color: isDark
            ? const Color(0xFF1F2937) // Один цвет вместо градиента
            : const Color(0xFF374151),
        child: SafeArea(
          child: Column(
            children: [
              // Верхняя панель
              // Верхняя панель
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Иконка штанги + название
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.fitness_center,
                            color: Colors.white,
                            size: 20, // ← меньше
                          ),
                        ),
                        const SizedBox(width: 8), // ← меньше отступ
                        Text(
                          'home.title'.tr(),
                          style: const TextStyle(
                            fontSize: 20, // ← меньше
                            fontWeight: FontWeight.w600, // ← не такой жирный
                            color: Colors.white,
                            letterSpacing: 0.5, // ← меньше
                          ),
                        ),
                      ],
                    ),
                    // Кнопки справа
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.trending_up,
                              color: Colors.white, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProgressPage(),
                              ),
                            );
                          },
                          tooltip: 'progress.title'.tr(),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.bar_chart,
                              color: Colors.white, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StatisticsPage(),
                              ),
                            );
                          },
                          tooltip: 'statistics.title'.tr(),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.history,
                              color: Colors.white, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HistoryPage(),
                              ),
                            ).then((_) {
                              _loadWorkoutCount();
                            });
                          },
                          tooltip: 'history.title'.tr(),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              color: Colors.white, size: 22),
                          padding: EdgeInsets.zero,
                          onSelected: (value) async {
                            // Язык
                            if (value == 'ru' ||
                                value == 'lv' ||
                                value == 'en') {
                              context.setLocale(Locale(value));
                              return;
                            }

                            // Экспорт
                            if (value == 'export') {
                              try {
                                await BackupService().exportData();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${'backup.export_error'.tr()}: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }

                            // Импорт
                            if (value == 'import') {
                              try {
                                final count =
                                    await BackupService().importData();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        count > 0
                                            ? 'backup.imported_count'.tr(
                                                namedArgs: {'count': '$count'})
                                            : 'backup.no_new_workouts'.tr(),
                                      ),
                                      backgroundColor: count > 0
                                          ? const Color(0xFF10B981)
                                          : Colors.grey,
                                    ),
                                  );
                                  if (count > 0) _loadWorkoutCount();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${'backup.import_error'.tr()}: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            // Языки
                            const PopupMenuItem(
                              value: 'ru',
                              child: Row(
                                children: [
                                  Text('🇷🇺', style: TextStyle(fontSize: 16)),
                                  SizedBox(width: 8),
                                  Text('Русский'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'lv',
                              child: Row(
                                children: [
                                  Text('🇱🇻', style: TextStyle(fontSize: 16)),
                                  SizedBox(width: 8),
                                  Text('Latviešu'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'en',
                              child: Row(
                                children: [
                                  Text('🇬🇧', style: TextStyle(fontSize: 16)),
                                  SizedBox(width: 8),
                                  Text('English'),
                                ],
                              ),
                            ),
                            // Разделитель
                            const PopupMenuDivider(),
                            // Экспорт
                            PopupMenuItem(
                              value: 'export',
                              child: Row(
                                children: [
                                  Icon(Icons.upload,
                                      color: Color(0xFFF97316), size: 20),
                                  SizedBox(width: 8),
                                  Text('backup.export'.tr()),
                                ],
                              ),
                            ),
                            // Импорт
                            PopupMenuItem(
                              value: 'import',
                              child: Row(
                                children: [
                                  Icon(Icons.download,
                                      color: Color(0xFFF97316), size: 20),
                                  SizedBox(width: 8),
                                  Text('backup.import'.tr()),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Основной контент
              Flexible(
                child: SingleChildScrollView(
                  // ← ДОБАВЬ ЭТУ СТРОКУ
                  physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Брутальная карточка
                          Card(
                            elevation: 4,
                            child: InkWell(
                              onTap: () {
                                // Открываем историю
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const HistoryPage(),
                                  ),
                                ).then((_) {
                                  // Обновляем счётчик когда вернёмся
                                  _loadWorkoutCount();
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(32.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDark
                                        ? [
                                            const Color(0xFF1F2937),
                                            const Color(0xFF374151),
                                          ]
                                        : [
                                            const Color(0xFF374151),
                                            const Color(0xFF475569),
                                          ],
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min, // ← ВАЖНО!
                                  children: [
                                    // Иконка с оранжевым фоном
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF97316),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFF97316)
                                                .withOpacity(0.4),
                                            blurRadius: 20,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.fitness_center,
                                        size: 48, // ← Уменьшил размер
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'home.total_workouts'.tr().toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 14, // ← Уменьшил
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[300],
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _isLoading ? '...' : '$_workoutCount',
                                      style: const TextStyle(
                                        fontSize: 56, // ← Уменьшил с 72
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF97316),
                                        height: 1,
                                      ),
                                    ),

                                    // Бейдж черновика
                                    if (_draftCount > 0) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF97316)
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: const Color(0xFFF97316),
                                            width: 2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.edit,
                                              color: Color(0xFFF97316),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'workout.draft'.tr(),
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.grey[200],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32), // ← Уменьшил отступ

// МОЩНАЯ ОРАНЖЕВАЯ КНОПКА
                          Container(
                            width: double.infinity, // ← На всю ширину
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFF97316).withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                // Создаём новую тренировку
                                final draft = await _service.getDraftWorkout();

                                if (draft != null) {
                                  // Есть черновик - открываем его
                                  if (context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => WorkoutEditorPage(
                                            workoutId: draft.id),
                                      ),
                                    ).then((_) {
                                      _loadWorkoutCount();
                                    });
                                  }
                                } else {
                                  // ← НОВАЯ ЛОГИКА: Показываем диалог для ввода названия
                                  final workoutName =
                                      await _showCreateWorkoutDialog();

                                  // Если пользователь отменил диалог (нажал "Отмена")
                                  if (workoutName == null) return;

                                  // Создаём новую тренировку с введённым названием
                                  final workout = await _service.createWorkout(
                                    date: _service.getTodayDate(),
                                    name: workoutName,
                                  );

                                  if (context.mounted) {
                                    // Открываем редактор
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => WorkoutEditorPage(
                                            workoutId: workout.id),
                                      ),
                                    ).then((_) {
                                      _loadWorkoutCount();
                                    });
                                  }
                                }
                              },
                              icon: Icon(
                                _currentWorkout != null
                                    ? Icons.play_arrow
                                    : Icons.add_circle, // ← Умная иконка
                                size: 28,
                              ),
                              label: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  (_currentWorkout != null
                                          ? 'workout.continue_workout'
                                          : 'home.start_workout')
                                      .tr()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _currentWorkout != null
                                    ? const Color(
                                        0xFFF97316) // Оранжевая если черновик
                                    : const Color(
                                        0xFF10B981), // Зелёная если нет
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
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

// Показать диалог для ввода названия новой тренировки
  Future<String?> _showCreateWorkoutDialog() async {
    // Очищаем поле и ставим название по умолчанию
    _newWorkoutNameController.text = 'workout.new_workout'.tr();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFF97316),
            width: 2,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_circle,
                color: Color(0xFFF97316),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'workout.create_workout_dialog_title'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'workout.create_workout_message'.tr(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // Поле "Название тренировки"
            TextField(
              controller: _newWorkoutNameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF374151),
                hintText: 'workout.workout_name_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(
                  Icons.fitness_center,
                  color: Color(0xFFF97316),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Кнопка "Отмена"
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              'workout.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          // Кнопка "Создать"
          ElevatedButton(
            onPressed: () {
              final name = _newWorkoutNameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('workout.workout_name_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, name);
            },
            child:
                Text('workout.create'.tr()), // "Добавить" как кнопка создания
          ),
        ],
      ),
    );

    return result;
  }

  @override
  void dispose() {
    _newWorkoutNameController.dispose();
    super.dispose();
  }
}
