import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'home_page.dart';
import 'history_page.dart';
import 'statistics_page.dart';
import 'progress_page.dart';
import 'settings_page.dart';
import '../widgets/active_workout_banner.dart';
import 'programs_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // Текущий выбранный таб
  int _currentIndex = 0;

  // Страницы — порядок совпадает с иконками навигации
  final List<Widget> _pages = [
    const HomePage(),
    const ProgramsPage(),
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
        children: _pages,
      ),

      // Баннер + навигация внизу
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Баннер активной тренировки
          const ActiveWorkoutBanner(),

          // Нижняя навигация
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            backgroundColor: const Color(0xFF0F172A),
            indicatorColor: const Color(0xFFF97316).withOpacity(0.2),
            surfaceTintColor: Colors.transparent,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.home, color: Color(0xFFF97316)),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.assignment, color: Color(0xFFF97316)),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.history, color: Color(0xFFF97316)),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.bar_chart, color: Color(0xFFF97316)),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.settings, color: Color(0xFFF97316)),
                label: '',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
