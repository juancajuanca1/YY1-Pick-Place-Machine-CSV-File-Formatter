import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neoden_yy1_formatter/features/providers.dart';
import 'package:neoden_yy1_formatter/features/home/home_navigation_button.dart';
import 'package:neoden_yy1_formatter/core/export/csv_export_writer.dart';

class ExportPreviewScreen extends ConsumerStatefulWidget {
  const ExportPreviewScreen({super.key});

  @override
  ConsumerState<ExportPreviewScreen> createState() =>
      _ExportPreviewScreenState();
}

class _ExportPreviewScreenState extends ConsumerState<ExportPreviewScreen> {
  static const _writer = CsvExportWriter();
  String? _previewContent;
  ExportValidationReport? _report;

  @override
  void initState() {
    super.initState();
    _buildPreview();
  }

  void _buildPreview() {
    final project = ref.read(projectProvider);
    if (project == null) return;
    final csv = _writer.write(project, sideFilter: project.exportSide);
    final report = _writer.validate(csv);
    setState(() {
      _previewContent = csv;
      _report = report;
    });
  }

  Future<void> _saveFile() async {
    final project = ref.read(projectProvider);
    if (project == null || _previewContent == null) return;

    final baseName =
        '${project.sourceFileName.replaceAll(RegExp(r'\.[^.]+$'), '')}_yy1.csv';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save YY1 CSV',
      fileName: baseName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (savePath == null) return;

    // On Linux the GTK picker doesn't auto-append the extension, so enforce it.
    final finalPath = savePath.toLowerCase().endsWith('.csv')
        ? savePath
        : '$savePath.csv';

    await File(finalPath).writeAsString(_previewContent!, flush: true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $finalPath'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final validation = ref.watch(validationProvider);
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Export Preview',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          const HomeNavigationButton(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: validation.canExport ? _saveFile : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Export YY1 CSV'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Validation report ─────────────────────────────────────────
          if (report != null && !report.isValid)
            Container(
              color: colors.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: colors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Export validation issues:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  for (final issue in report.issues)
                    Padding(
                      padding: const EdgeInsets.only(left: 26, top: 4),
                      child: Text(
                        issue,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: colors.error),
                      ),
                    ),
                ],
              ),
            ),

          if (report != null && report.isValid)
            Container(
              color: Colors.green.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'All rows pass structural validation.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),

          // ── Warnings ─────────────────────────────────────────────────
          if (validation.warnings.isNotEmpty)
            Container(
              color: Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final w in validation.warnings)
                    Text(
                      '⚠  $w',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade900,
                      ),
                    ),
                ],
              ),
            ),

          // ── CSV preview ───────────────────────────────────────────────
          Expanded(
            child: _previewContent == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _previewContent!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
