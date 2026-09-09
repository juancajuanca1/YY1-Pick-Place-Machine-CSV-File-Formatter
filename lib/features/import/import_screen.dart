import 'dart:io';
import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neoden_yy1_formatter/features/providers.dart';
import 'package:neoden_yy1_formatter/features/schema_review/schema_review_screen.dart';
import 'package:neoden_yy1_formatter/features/assignment/placement_assignment_screen.dart';
import 'package:neoden_yy1_formatter/core/normalize/normalization_service.dart';
import 'package:neoden_yy1_formatter/features/home/home_navigation_button.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});
  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  bool _isDragging = false;

  Future<void> _handleFile(String path) async {
    final name = path.split(Platform.pathSeparator).last;
    ref.read(rawFileProvider.notifier).setLoading(name);
    ref.read(projectProvider.notifier).reset();
    ref.read(resolvedSchemaProvider.notifier).reset();

    try {
      final bytes = await File(path).readAsBytes();
      String content;
      // UTF-16 LE (FF FE BOM)
      if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
        final chars = <int>[];
        for (int i = 2; i + 1 < bytes.length; i += 2) {
          chars.add(bytes[i] | (bytes[i + 1] << 8));
        }
        content = String.fromCharCodes(chars);
      }
      // UTF-16 BE (FE FF BOM)
      else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
        final chars = <int>[];
        for (int i = 2; i + 1 < bytes.length; i += 2) {
          chars.add((bytes[i] << 8) | bytes[i + 1]);
        }
        content = String.fromCharCodes(chars);
      } else {
        try {
          content = utf8.decode(bytes, allowMalformed: false);
        } catch (_) {
          content = latin1.decode(bytes);
        }
      }
      ref.read(rawFileProvider.notifier).setContent(name, content);
    } catch (e) {
      ref.read(rawFileProvider.notifier).setError('Could not read file: $e');
      return;
    }

    // Wait for providers to update then route
    await Future.delayed(Duration.zero);

    final match = ref.read(schemaMatchProvider);
    if (match == null) return;

    if (!mounted) return;

    if (match.isHighConfidence) {
      // Auto-accept and proceed straight to assignment
      ref.read(resolvedSchemaProvider.notifier).accept(match);
      final doc = ref.read(tabularDocumentProvider);
      final schema = ref.read(resolvedSchemaProvider);
      if (doc != null && schema != null) {
        final records = NormalizationService.normalizeRows(doc, schema);
        ref.read(projectProvider.notifier).load(records, name);
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PlacementAssignmentScreen(),
            ),
          );
        }
      }
    } else {
      // Low confidence – show schema review
      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SchemaReviewScreen()));
      }
    }
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'pos', 'txt'],
      dialogTitle: 'Select placement/pick-and-place file',
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path != null) await _handleFile(path);
  }

  @override
  Widget build(BuildContext context) {
    final raw = ref.watch(rawFileProvider);
    final match = ref.watch(schemaMatchProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leadingWidth: 100,
        leading: const HomeNavigationButton(),
        title: const Text('NeoDen YY1 Formatter'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.memory_rounded, size: 52, color: colors.primary),
                  const SizedBox(height: 12),
                  Text(
                    'NeoDen YY1 Formatter',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Import any placement/pick-and-place file — EasyEDA, KiCad, Altium, Fusion 360 and more',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use millimeters (mm). Coordinates are preserved at exact 1:1 scale in the YY1 output.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ── Drop zone ──────────────────────────────────────────────
                  DropTarget(
                    onDragDone: (d) {
                      setState(() => _isDragging = false);
                      if (d.files.isNotEmpty) _handleFile(d.files.first.path);
                    },
                    onDragEntered: (_) => setState(() => _isDragging = true),
                    onDragExited: (_) => setState(() => _isDragging = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: double.infinity,
                      height: 210,
                      decoration: BoxDecoration(
                        color: _isDragging
                            ? colors.primaryContainer
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isDragging
                              ? colors.primary
                              : colors.outlineVariant,
                          width: _isDragging ? 2.5 : 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_file_rounded,
                            size: 48,
                            color: _isDragging
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isDragging
                                ? 'Drop it!'
                                : 'Drag & drop your placement file here',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: _isDragging
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '.csv  •  .pos  •  .txt',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: raw.isLoading ? null : _pickFile,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Select File'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  if (raw.isLoading)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Parsing file…'),
                      ],
                    ),

                  if (!raw.isLoading && raw.error != null)
                    _Banner(
                      icon: Icons.error_outline_rounded,
                      color: colors.error,
                      bg: colors.errorContainer,
                      text: raw.error!,
                    ),

                  // Diagnostics preview – if schema was run but confidence low
                  if (!raw.isLoading &&
                      match != null &&
                      !match.isHighConfidence)
                    _Banner(
                      icon: Icons.info_outline_rounded,
                      color: colors.secondary,
                      bg: colors.secondaryContainer,
                      text:
                          'Some fields could not be detected automatically. '
                          'You will be asked to confirm the column mapping.',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String text;
  const _Banner({
    required this.icon,
    required this.color,
    required this.bg,
    required this.text,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
