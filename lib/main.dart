import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: Yy1FormatterApp()));
}

class Yy1FormatterApp extends StatelessWidget {
  const Yy1FormatterApp({super.key});

  @override
  Widget build(BuildContext context) {
    const aggieMaroon = Color(0xFF500000);
    final lightColors =
        ColorScheme.fromSeed(
          seedColor: aggieMaroon,
          brightness: Brightness.light,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ).copyWith(
          primary: aggieMaroon,
          secondary: const Color(0xFF732F2F),
          tertiary: const Color(0xFF998542),
        );
    final darkColors =
        ColorScheme.fromSeed(
          seedColor: aggieMaroon,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ).copyWith(
          primary: const Color(0xFFFFB3B3),
          secondary: const Color(0xFFE8B4B4),
          tertiary: const Color(0xFFE4D28C),
        );
    return MaterialApp(
      title: 'Texas A&M PCB Workshop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColors,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: aggieMaroon,
          foregroundColor: Colors.white,
        ),
        cardTheme: const CardThemeData(elevation: 0),
        inputDecorationTheme: const InputDecorationTheme(isDense: true),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColors,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: aggieMaroon,
          foregroundColor: Colors.white,
        ),
        cardTheme: const CardThemeData(elevation: 0),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
