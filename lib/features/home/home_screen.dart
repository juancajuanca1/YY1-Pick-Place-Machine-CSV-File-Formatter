import 'package:flutter/material.dart';
import '../import/import_screen.dart';
import '../stencil/stencil_generator_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PCB Workshop')),
    body: Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Text(
                'What would you like to make?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _HomeCard(
                    icon: Icons.precision_manufacturing_outlined,
                    title: 'NeoDen YY1 Formatter',
                    description: 'Convert placement files and assign feeders.',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ImportScreen()),
                    ),
                  ),
                  _HomeCard(
                    icon: Icons.content_cut_rounded,
                    title: 'Cricut Stencil Generator',
                    description:
                        'Load a Gerber folder and export top/bottom paste SVGs.',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StencilGeneratorScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final VoidCallback onTap;
  const _HomeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 340,
    height: 300,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(description),
            ],
          ),
        ),
      ),
    ),
  );
}
