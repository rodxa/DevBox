import 'package:devbox/home.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.blueGrey,
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.windows: _FadeSlidePageTransitionBuilder(),
            TargetPlatform.linux: _FadeSlidePageTransitionBuilder(),
            TargetPlatform.macOS: _FadeSlidePageTransitionBuilder(),
            TargetPlatform.android: _FadeSlidePageTransitionBuilder(),
            TargetPlatform.iOS: _FadeSlidePageTransitionBuilder(),
          },
        ),
      ),
      home: Home(),
    );
  }
}

class _FadeSlidePageTransitionBuilder extends PageTransitionsBuilder {
  const _FadeSlidePageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(0.1, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));
    final fade = CurvedAnimation(
      parent: animation,
      curve: Curves.easeIn,
    );
    return SlideTransition(
      position: slide,
      child: FadeTransition(
        opacity: fade,
        child: child,
      ),
    );
  }
}


