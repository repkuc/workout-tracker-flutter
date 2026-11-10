import 'package:flutter/widgets.dart';

// Наблюдатель за страницами навигатора (подключён в MaterialApp.navigatorObservers).
// MainPage по нему узнаёт, что поверх неё открыт другой экран (редактор и т.п.).
// Только PageRoute: диалоги и bottom sheet не закрывают вкладку целиком.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

// Видна ли сейчас вкладка (или баннер) MainPage: выбрана в нижнем меню и
// не закрыта другим экраном. Без предка — считается видимой.
class TabVisibility extends InheritedWidget {
  final bool visible;

  const TabVisibility({super.key, required this.visible, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabVisibility>()?.visible ??
      true;

  @override
  bool updateShouldNotify(TabVisibility oldWidget) =>
      visible != oldWidget.visible;
}

// Ленивая перезагрузка по WorkoutService.dataChanged: видимый виджет
// перезагружается сразу, скрытый только помечает себя «устаревшим» и
// перезагружается один раз, когда снова становится видимым. Так отметки
// подходов в редакторе не заставляют все вкладки под ним перечитывать историю.
// Подписка: dataChanged.addListener(onWorkoutDataChanged).
mixin ReloadWhenVisible<T extends StatefulWidget> on State<T> {
  bool _reloadPending = false;
  bool _isVisible = true;

  // Перезагрузить данные (без спиннера: старое видно, пока грузится новое)
  void reloadVisibleData();

  void onWorkoutDataChanged() {
    if (!mounted) return;
    if (_isVisible) {
      reloadVisibleData();
    } else {
      _reloadPending = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TabVisibility.of(context);
    if (visible == _isVisible) return;
    _isVisible = visible;
    if (visible && _reloadPending) {
      _reloadPending = false;
      // После текущего кадра: в didChangeDependencies setState нельзя
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) reloadVisibleData();
      });
    }
  }
}
