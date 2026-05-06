import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/import/import_screen.dart';

void main() {
  runApp(const ProviderScope(child: Yy1FormatterApp()));
}

class Yy1FormatterApp extends StatelessWidget {
  const Yy1FormatterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeoDen YY1 Formatter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: const CardThemeData(elevation: 0),
        inputDecorationTheme: const InputDecorationTheme(isDense: true),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: const CardThemeData(elevation: 0),
      ),
      themeMode: ThemeMode.system,
      home: const ImportScreen(),
    );
  }
}

