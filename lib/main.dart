import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'services/workout_service.dart';

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
      startLocale: const Locale('ru'),
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
        cardTheme: CardTheme(
          elevation: 8,
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
        cardTheme: CardTheme(
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
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Брутальный градиент (чёрный → тёмно-серый)
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A), // Глубокий чёрный
                    const Color(0xFF1F2937), // Тёмно-серый
                    const Color(0xFF374151), // Серый (без красного!)
                  ]
                : [
                    const Color(0xFF1F2937), // Тёмно-серый
                    const Color(0xFF374151), // Серый
                    const Color(0xFF4B5563), // Светло-серый
                  ],
          ),
        ),
        child: SafeArea(
            child: Column(
              children: [
                // Верхняя панель
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Иконка штанги + название
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316), // ← ОРАНЖЕВЫЙ
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.fitness_center,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'home.title'.tr(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      PopupMenuButton<Locale>(
                        icon: const Icon(Icons.language,
                            color: Colors.white, size: 28),
                        onSelected: (Locale locale) {
                          context.setLocale(locale);
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem(
                            value: Locale('ru'),
                            child: Text('🇷🇺 Русский'),
                          ),
                          const PopupMenuItem(
                            value: Locale('lv'),
                            child: Text('🇱🇻 Latviešu'),
                          ),
                          const PopupMenuItem(
                            value: Locale('en'),
                            child: Text('🇬🇧 English'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Основной контент
                Flexible(
                  child: SingleChildScrollView(  // ← ДОБАВЬ ЭТУ СТРОКУ
    physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Брутальная карточка
                          // Брутальная карточка
                          Card(
                            elevation: 12,
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
                                        borderRadius: BorderRadius.circular(20),
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
                                            'Черновик',
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
                                final workout = await _service.createWorkout(
                                  date: _service.getTodayDate(),
                                  name: 'workout.new_workout'.tr(),
                                );

                                // Показываем уведомление
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle,
                                              color: Colors.white),
                                          const SizedBox(width: 8),
                                          Text('Тренировка создана! 🔥'),
                                        ],
                                      ),
                                      backgroundColor: const Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );

                                  // Обновляем счётчик
                                  _loadWorkoutCount();
                                }
                              },
                              icon: const Icon(Icons.add_circle, size: 28),
                              label: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'home.start_workout'.tr().toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 16, // ← Чуть меньше
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
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
}
