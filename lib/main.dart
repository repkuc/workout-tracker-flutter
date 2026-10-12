import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'services/workout_service.dart';
import 'pages/main_page.dart';
import 'services/exercise_library_service.dart';
import 'theme/app_colors.dart';

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
          primary: AppColors.accent, // ОРАНЖЕВЫЙ (энергия)
          secondary: AppColors.themeLightSecondary, // Тёмно-оранжевый
          tertiary: AppColors.success, // Зелёный (успех)
          surface: AppColors.themeLightSurface, // Светло-серый
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.themeLightAppBar, // Тёмно-серый (металл)
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
            backgroundColor: AppColors.accent, // Оранжевый (как в тёмной теме)
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            borderSide: const BorderSide(color: AppColors.themeLightInputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.themeLightInputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 2),
          ),
        ),
      ),

      // ТЁМНАЯ ТЕМА - Брутальная (чёрный + красный)
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.themeDarkPrimary, // Ярко-оранжевый
          secondary: AppColors.accent, // Оранжевый
          tertiary: AppColors.success, // Зелёный (успех)
          surface: AppColors.themeDarkSurface, // Почти чёрный
          onPrimary: Colors.white,
          onSecondary: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background, // Глубокий чёрный
          foregroundColor: Colors.white,
          elevation: 4,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: AppColors.themeDarkCard, // Тёмно-серый
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent, // Оранжевый
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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




