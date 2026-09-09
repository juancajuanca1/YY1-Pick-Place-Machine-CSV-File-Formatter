import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neoden_yy1_formatter/features/providers.dart';
import 'package:neoden_yy1_formatter/features/assignment/placement_assignment_screen.dart';
import 'package:neoden_yy1_formatter/core/models/resolved_schema.dart';
import 'package:neoden_yy1_formatter/core/normalize/normalization_service.dart';
import 'package:neoden_yy1_formatter/features/home/home_navigation_button.dart';

class SchemaReviewScreen extends ConsumerStatefulWidget {
  const SchemaReviewScreen({super.key});

  @override
  ConsumerState<SchemaReviewScreen> createState() => _SchemaReviewScreenState();
}

class _SchemaReviewScreenState extends ConsumerState<SchemaReviewScreen> {
  late Map<CanonicalField, int> _mapping;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      final match = ref.read(schemaMatchProvider);
      _mapping = Map.from(match?.resolvedColumns ?? {});
      _initialised = true;
    }
  }

  void _proceed() {
    final doc = ref.read(tabularDocumentProvider);
    final rawFile = ref.read(rawFileProvider);
    if (doc == null) return;

    ref.read(resolvedSchemaProvider.notifier).confirm(_mapping);
    final schema = ref.read(resolvedSchemaProvider)!;
    final records = NormalizationService.normalizeRows(doc, schema);
    ref
        .read(projectProvider.notifier)
        .load(records, rawFile.fileName ?? 'unknown');

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PlacementAssignmentScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final match = ref.watch(schemaMatchProvider);
    final doc = ref.watch(tabularDocumentProvider);
    final colors = Theme.of(context).colorScheme;

    if (match == null || doc == null) {
      return const Scaffold(body: Center(child: Text('No file loaded.')));
    }

    final columnOptions = [
      const DropdownMenuItem<int>(value: -1, child: Text('— not mapped —')),
      for (int i = 0; i < doc.originalHeaders.length; i++)
        DropdownMenuItem<int>(
          value: i,
          child: Text(
            '[$i] ${doc.originalHeaders[i]}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Confirm Column Mapping',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          const HomeNavigationButton(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _proceed,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Confirm & Continue'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // ── Mapping editor ──────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'We detected the following column mapping. '
                  'Please verify and correct any mistakes before continuing.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                ...CanonicalField.values.map((field) {
                  return _MappingRow(
                    field: field,
                    currentIndex: _mapping[field] ?? -1,
                    confidence: match.confidence[field] ?? 0.0,
                    options: columnOptions,
                    onChanged: (v) => setState(() {
                      if (v == -1) {
                        _mapping.remove(field);
                      } else {
                        _mapping[field] = v!;
                      }
                    }),
                  );
                }),
              ],
            ),
          ),

          VerticalDivider(width: 1, color: colors.outlineVariant),

          // ── Diagnostics panel ───────────────────────────────────────────
          Expanded(flex: 2, child: _DiagnosticsPanel(match: match)),
        ],
      ),
    );
  }
}

class _MappingRow extends StatelessWidget {
  final CanonicalField field;
  final int currentIndex;
  final double confidence;
  final List<DropdownMenuItem<int>> options;
  final ValueChanged<int?> onChanged;

  const _MappingRow({
    required this.field,
    required this.currentIndex,
    required this.confidence,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pct = (confidence * 100).toInt();
    final isResolved = currentIndex >= 0;
    final indicatorColor = !isResolved
        ? (field.isRequired ? colors.error : colors.onSurfaceVariant)
        : confidence >= 0.70
        ? Colors.green
        : Colors.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: indicatorColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  field.isRequired ? 'required' : 'optional',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: currentIndex,
              items: options,
              onChanged: onChanged,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              isResolved ? '$pct%' : '—',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: indicatorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsPanel extends StatelessWidget {
  final SchemaMatchResult match;
  const _DiagnosticsPanel({required this.match});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inference Diagnostics',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: match.diagnostics.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  match.diagnostics[i],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: match.diagnostics[i].contains('NOT FOUND')
                        ? colors.error
                        : colors.onSurface,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
