import 'package:flutter/material.dart';

/// Returns from any workflow step to the application's home menu.
class HomeNavigationButton extends StatelessWidget {
  const HomeNavigationButton({super.key});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
    icon: const Icon(Icons.home_outlined),
    label: const Text('Home'),
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
    ),
  );
}
