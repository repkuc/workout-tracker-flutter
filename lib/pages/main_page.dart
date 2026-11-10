import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'home_page.dart';
import 'history_page.dart';
import 'statistics_page.dart';
import 'progress_page.dart';
import 'settings_page.dart';
import '../widgets/active_workout_banner.dart';
import 'programs_page.dart';
import '../theme/app_colors.dart';
import '../widgets/tab_visibility.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with RouteAware {
  // Текущий выбранный таб
  int _currentIndex = 0;
  // Поверх MainPage открыт другой экран (редактор, детали программы…) —
  // тогда не видна ни одна вкладка и баннер.
  bool _covered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() => setState(() => _covered = true);

  @override
  void didPopNext() => setState(() => _covered = false);

  bool _isVisible(int index) => !_covered && _currentIndex == index;

  // Страницы — порядок совпадает с иконками навигации.
  // IndexedStack строит все вкладки сразу, поэтому каждой сообщаем, видна ли
  // она (TabVisibility): скрытые не перечитывают историю на каждое изменение,
  // а один раз при показе (см. ReloadWhenVisible). «Программам» — ещё и
  // isActive: при показе она пересортирует список и снимет точку «новое».
  List<Widget> get _pages => [
        const HomePage(),
        ProgramsPage(isActive: _isVisible(1)),
        const HistoryPage(),
        const StatisticsPage(),
        const SettingsPage(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        key: ValueKey(context.locale),
        children: [
          for (final (i, page) in _pages.indexed)
            TabVisibility(visible: _isVisible(i), child: page),
        ],
      ),

      // Баннер + навигация внизу
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Баннер активной тренировки
          TabVisibility(
              visible: !_covered, child: const ActiveWorkoutBanner()),

          // Нижняя навигация
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            backgroundColor: AppColors.background,
            indicatorColor: AppColors.accent.withOpacity(0.2),
            surfaceTintColor: Colors.transparent,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: AppColors.inactive),
                selectedIcon: Icon(Icons.home, color: AppColors.accent),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined, color: AppColors.inactive),
                selectedIcon: Icon(Icons.assignment, color: AppColors.accent),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined, color: AppColors.inactive),
                selectedIcon: Icon(Icons.history, color: AppColors.accent),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined, color: AppColors.inactive),
                selectedIcon: Icon(Icons.bar_chart, color: AppColors.accent),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined, color: AppColors.inactive),
                selectedIcon: Icon(Icons.settings, color: AppColors.accent),
                label: '',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
