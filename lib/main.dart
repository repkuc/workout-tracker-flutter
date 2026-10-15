import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

      // Приложение задумано только тёмным: одна тёмная тема при любом
      // системном режиме (светлом или тёмном), чтобы всё выглядело одинаково.
      theme: ThemeData(
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
        // Все SnackBar — «плавающие» со скруглёнными углами.
        // Цвет задаём по смыслу в месте вызова: success — успех, danger — ошибка,
        // snackbarNeutral — нейтральное сообщение (он же цвет по умолчанию).
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.snackbarNeutral,
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      themeMode: ThemeMode.dark,
      // Светлые иконки статус-бара на тёмном фоне — в любом системном режиме
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light, // Android
          statusBarBrightness: Brightness.dark, // iOS
        ),
        child: child!,
      ),
      home: const MainPage(),
    );
  }
}




