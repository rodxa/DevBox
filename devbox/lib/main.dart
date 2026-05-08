import 'package:devbox/home.dart';
import 'package:flutter/foundation.dart';
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
      home: kIsWeb ? const _WebNotSupportedPage() : Home(),
    );
  }
}

class _WebNotSupportedPage extends StatelessWidget {
  const _WebNotSupportedPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.web_asset_off, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Web preview is not supported for this app yet.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'This project currently uses local filesystem and process APIs that only work on desktop platforms.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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


