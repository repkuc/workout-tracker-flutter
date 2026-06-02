import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'services/workout_service.dart';
import 'pages/main_page.dart';
import 'services/exercise_library_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Инициализируем сервис работы с тренировками
  final workoutService = WorkoutService();
  await workoutService.init();

  final exerciseLibrary = ExerciseLibraryService(); // Получаем доступ к сервису библиотеки упражнений
  await exerciseLibrary.migrateExistingExercises(); // Выполняем миграцию упражнений из истории в библиотеку

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
      home: const MainPage(),
    );
  }
}




