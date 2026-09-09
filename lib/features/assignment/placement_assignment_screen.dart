import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neoden_yy1_formatter/features/providers.dart';
import 'package:neoden_yy1_formatter/features/export_preview/export_preview_screen.dart';
import 'package:neoden_yy1_formatter/core/grouping/grouping_service.dart';
import 'package:neoden_yy1_formatter/core/models/placement_project.dart';
import 'package:neoden_yy1_formatter/core/models/placement_record.dart';
import 'package:neoden_yy1_formatter/core/models/board_side.dart';
import 'package:neoden_yy1_formatter/features/home/home_navigation_button.dart';

// ── Column widths ─────────────────────────────────────────────────────────────
const double _wDot = 20;
const double _wRef = 80;
const double _wVal = 108;
const double _wFp = 128;
const double _wSide = 52;
const double _wX = 76;
const double _wY = 76;
const double _wSlot = 72;
const double _wSpeed = 76;
const double _wPick = 76;
const double _wPlace = 76;
const double _wAct = 76; // delete + toggle

double get _tableWidth =>
    _wDot +
    _wRef +
    _wVal +
    _wFp +
    _wSide +
    _wX +
    _wY +
    _wSlot +
    _wSpeed +
    _wPick +
    _wPlace +
    _wAct;

// ── Screen ────────────────────────────────────────────────────────────────────
class PlacementAssignmentScreen extends ConsumerWidget {
  const PlacementAssignmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final validation = ref.watch(validationProvider);
    final colors = Theme.of(context).colorScheme;

    if (project == null) {
      return const Scaffold(body: Center(child: Text('No project loaded.')));
    }

    final groups = GroupingService.buildGroups(project.records);
    final dupeSlots = project.duplicateSlots;

    // Build flat list for current export side
    final items = <_Item>[];
    for (final g in groups) {
      final visible = g.records
          .where((r) => r.side == project.exportSide)
          .toList();
      if (visible.isEmpty) continue;
      items.add(_GroupItem(g));
      for (final r in visible) {
        items.add(_RecordItem(r, dupeSlots.contains(r.feederSlot)));
      }
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assign Feeders',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              project.sourceFileName,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          const HomeNavigationButton(),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _SideSelector(
              selected: project.exportSide,
              onChanged: (s) =>
                  ref.read(projectProvider.notifier).setExportSide(s),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _GlobalParamBar(),
          _StatsBar(project: project),
          if (dupeSlots.isNotEmpty) _DupeWarning(dupeSlots: dupeSlots),
          // Horizontally scrollable table
          Expanded(child: _HScrollTable(items: items)),
          _ExportBar(validation: validation),
        ],
      ),
    );
  }
}

// ── Horizontally-scrollable table ─────────────────────────────────────────────
class _HScrollTable extends StatefulWidget {
  final List<_Item> items;
  const _HScrollTable({required this.items});
  @override
  State<_HScrollTable> createState() => _HScrollTableState();
}

class _HScrollTableState extends State<_HScrollTable> {
  final _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If window is wider than the table, centre it; otherwise scroll
        final totalW = _tableWidth + 24; // +24 px horizontal padding
        final useScroll = constraints.maxWidth < totalW;

        Widget table = Column(
          children: [
            _TableHeader(),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: widget.items.length,
                itemBuilder: (_, i) {
                  final item = widget.items[i];
                  if (item is _GroupItem) {
                    return _GroupHeaderRow(group: item.group);
                  }
                  final ri = item as _RecordItem;
                  return _ComponentRow(
                    record: ri.record,
                    isDuplicate: ri.isDuplicate,
                  );
                },
              ),
            ),
          ],
        );

        if (useScroll) {
          return Scrollbar(
            controller: _hScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _hScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: totalW, child: table),
            ),
          );
        }

        // Wide enough: centre the fixed-width table
        return Center(
          child: SizedBox(width: totalW, child: table),
        );
      },
    );
  }
}

// ── Item types ────────────────────────────────────────────────────────────────
abstract class _Item {}

class _GroupItem extends _Item {
  final AssignmentGroup group;
  _GroupItem(this.group);
}

class _RecordItem extends _Item {
  final PlacementRecord record;
  final bool isDuplicate;
  _RecordItem(this.record, this.isDuplicate);
}

// ── Side selector ─────────────────────────────────────────────────────────────
class _SideSelector extends StatelessWidget {
  final BoardSide selected;
  final ValueChanged<BoardSide> onChanged;
  const _SideSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => SegmentedButton<BoardSide>(
    segments: const [
      ButtonSegment(value: BoardSide.top, label: Text('Top')),
      ButtonSegment(value: BoardSide.bottom, label: Text('Bottom')),
    ],
    selected: {selected},
    onSelectionChanged: (s) => onChanged(s.first),
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? const Color(0xFFFFF4F2)
            : Colors.white.withValues(alpha: 0.14);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? const Color(0xFF500000)
            : Colors.white;
      }),
      iconColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? const Color(0xFF500000)
            : Colors.white;
      }),
      side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFFF2D8D5))),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

// ── Global parameter bar ──────────────────────────────────────────────────────
class _GlobalParamBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GlobalParamBar> createState() => _GlobalParamBarState();
}

class _GlobalParamBarState extends ConsumerState<_GlobalParamBar> {
  final _speedCtrl = TextEditingController(text: '100');
  final _pickCtrl = TextEditingController(text: '0.0');
  final _placeCtrl = TextEditingController(text: '0.0');

  @override
  void dispose() {
    _speedCtrl.dispose();
    _pickCtrl.dispose();
    _placeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _ParamField(
            label: 'Speed (%)',
            controller: _speedCtrl,
            suffix: '%',
            isInt: true,
            onApply: () {
              final v = int.tryParse(_speedCtrl.text.trim());
              if (v != null) {
                ref.read(projectProvider.notifier).applyGlobalSpeed(v);
              }
            },
          ),
          _ParamField(
            label: 'Pick Height (mm)',
            controller: _pickCtrl,
            suffix: 'mm',
            onApply: () {
              final v = double.tryParse(_pickCtrl.text.trim());
              if (v != null) {
                ref.read(projectProvider.notifier).applyGlobalPickHeight(v);
              }
            },
          ),
          _ParamField(
            label: 'Place Height (mm)',
            controller: _placeCtrl,
            suffix: 'mm',
            onApply: () {
              final v = double.tryParse(_placeCtrl.text.trim());
              if (v != null) {
                ref.read(projectProvider.notifier).applyGlobalPlaceHeight(v);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ParamField extends StatelessWidget {
  final String label, suffix;
  final TextEditingController controller;
  final bool isInt;
  final VoidCallback onApply;
  const _ParamField({
    required this.label,
    required this.controller,
    required this.suffix,
    required this.onApply,
    this.isInt = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: isInt
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                isInt ? RegExp(r'\d') : RegExp(r'[\d.]'),
              ),
            ],
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              suffixText: suffix,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: (_) => onApply(),
          ),
        ),
        const SizedBox(width: 6),
        FilledButton.tonal(
          onPressed: onApply,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Apply All', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

// ── Stats bar ─────────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final PlacementProject project;
  const _StatsBar({required this.project});

  @override
  Widget build(BuildContext context) {
    final total = project.records.length;
    final onSide = project.records
        .where((r) => r.side == project.exportSide)
        .length;
    final assigned = project.records
        .where(
          (r) =>
              r.side == project.exportSide &&
              (r.feederSlot != null || r.isFiducial),
        )
        .length;
    final fiducials = project.records
        .where((r) => r.side == project.exportSide && r.isFiducial)
        .length;
    final colors = Theme.of(context).colorScheme;

    return Container(
      color: colors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Stat('Total', '$total'),
          const SizedBox(width: 24),
          _Stat('${project.exportSide.label}-side', '$onSide'),
          const SizedBox(width: 24),
          _Stat('Slots assigned', '$assigned / $onSide'),
          if (fiducials > 0) ...[
            const SizedBox(width: 24),
            _Stat('Fiducials', '$fiducials (exempt)'),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '$value  ',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

// ── Dupe warning ──────────────────────────────────────────────────────────────
class _DupeWarning extends StatelessWidget {
  final List<int> dupeSlots;
  const _DupeWarning({required this.dupeSlots});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Duplicate feeder slots: ${dupeSlots.join(', ')}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Table header ──────────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final s = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return Container(
      color: colors.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(width: _wDot),
          SizedBox(
            width: _wRef,
            child: Text('Ref.', style: s),
          ),
          SizedBox(
            width: _wVal,
            child: Text('Value', style: s),
          ),
          SizedBox(
            width: _wFp,
            child: Text('Footprint', style: s),
          ),
          SizedBox(
            width: _wSide,
            child: Text('Side', style: s),
          ),
          SizedBox(
            width: _wX,
            child: Text('Mid X (mm)', style: s, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: _wY,
            child: Text('Mid Y (mm)', style: s, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: _wSlot,
            child: Text('Feeder #', style: s, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: _wSpeed,
            child: Text('Speed %', style: s, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: _wPick,
            child: Text('Pick H.', style: s, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: _wPlace,
            child: Text('Place H.', style: s, textAlign: TextAlign.center),
          ),
          SizedBox(width: _wAct),
        ],
      ),
    );
  }
}

// ── Group section header ──────────────────────────────────────────────────────
class _GroupHeaderRow extends StatelessWidget {
  final AssignmentGroup group;
  const _GroupHeaderRow({required this.group});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: colors.primary.withValues(alpha: isDark ? 0.16 : 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        children: [
          Icon(Icons.layers_outlined, size: 14, color: colors.primary),
          const SizedBox(width: 6),
          Text(
            '${group.displayValue}  ·  ${group.displayFootprint}  ·  ${group.side.label}  ·  ${group.records.length} placement${group.records.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Component row ─────────────────────────────────────────────────────────────
class _ComponentRow extends ConsumerWidget {
  final PlacementRecord record;
  final bool isDuplicate;
  const _ComponentRow({required this.record, required this.isDuplicate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isFiducial = record.isFiducial;
    final dotColor = isDuplicate
        ? colors.error
        : isFiducial
        ? Colors.teal
        : record.feederSlot != null
        ? Colors.green
        : colors.outlineVariant;
    final dimmed = !record.enabled;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) =>
          _showComponentMenu(context, ref, details.globalPosition),
      child: Container(
        decoration: BoxDecoration(
          color: isFiducial
              ? Colors.teal.withValues(alpha: 0.06)
              : dimmed
              ? colors.surfaceContainerLowest
              : null,
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Row(
          children: [
            // Status dot
            SizedBox(
              width: _wDot,
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            // Designator chip
            SizedBox(
              width: _wRef,
              child: _chip(
                context,
                record.designator,
                dimmed,
                isFiducial,
                colors,
              ),
            ),
            // Value
            SizedBox(
              width: _wVal,
              child: Text(
                record.value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: dimmed
                      ? colors.onSurfaceVariant.withValues(alpha: 0.4)
                      : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Footprint
            SizedBox(
              width: _wFp,
              child: Text(
                record.footprint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Side
            SizedBox(
              width: _wSide,
              child: Text(
                record.side.label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            // Mid X
            SizedBox(
              width: _wX,
              child: Text(
                record.xMm.toStringAsFixed(3),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            // Mid Y
            SizedBox(
              width: _wY,
              child: Text(
                record.yMm.toStringAsFixed(3),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            // Feeder slot – fiducials show a "Fiducial" badge instead of input
            SizedBox(
              width: _wSlot,
              child: isFiducial
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.teal.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Fiducial',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.teal.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _InlineField(
                      value: record.feederSlot?.toString() ?? '',
                      hint: '—',
                      isInt: true,
                      isDuplicate: isDuplicate,
                      onChanged: (v) => ref
                          .read(projectProvider.notifier)
                          .setFeederSlot(record.id, int.tryParse(v)),
                    ),
            ),
            // Speed
            SizedBox(
              width: _wSpeed,
              child: _EditableCell(
                value: '${record.mountSpeed}',
                suffix: '%',
                isInt: true,
                onSave: (v) {
                  final iv = int.tryParse(v);
                  if (iv != null) {
                    ref
                        .read(projectProvider.notifier)
                        .setMountSpeed(record.id, iv);
                  }
                },
              ),
            ),
            // Pick height
            SizedBox(
              width: _wPick,
              child: _EditableCell(
                value: record.pickHeight.toStringAsFixed(1),
                suffix: 'mm',
                onSave: (v) {
                  final dv = double.tryParse(v);
                  if (dv != null) {
                    ref
                        .read(projectProvider.notifier)
                        .setPickHeight(record.id, dv);
                  }
                },
              ),
            ),
            // Place height
            SizedBox(
              width: _wPlace,
              child: _EditableCell(
                value: record.placeHeight.toStringAsFixed(1),
                suffix: 'mm',
                onSave: (v) {
                  final dv = double.tryParse(v);
                  if (dv != null) {
                    ref
                        .read(projectProvider.notifier)
                        .setPlaceHeight(record.id, dv);
                  }
                },
              ),
            ),
            // Actions: toggle visibility + delete
            SizedBox(
              width: _wAct,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      record.enabled ? Icons.visibility : Icons.visibility_off,
                      size: 17,
                      color: record.enabled
                          ? colors.primary
                          : colors.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                    tooltip: record.enabled
                        ? 'Exclude from export'
                        : 'Include in export',
                    onPressed: () => ref
                        .read(projectProvider.notifier)
                        .toggleEnabled(record.id),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 17,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    tooltip: 'Remove component',
                    onPressed: () => _confirmDelete(context, ref, record),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showComponentMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        PopupMenuItem(
          value: record.isFiducial ? 'component' : 'fiducial',
          child: Row(
            children: [
              Icon(
                record.isFiducial
                    ? Icons.memory_outlined
                    : Icons.gps_fixed_rounded,
              ),
              const SizedBox(width: 10),
              Text(
                record.isFiducial ? 'Treat as component' : 'Mark as fiducial',
              ),
            ],
          ),
        ),
        if (record.fiducialOverride != null)
          const PopupMenuItem(
            value: 'automatic',
            child: Row(
              children: [
                Icon(Icons.auto_awesome_outlined),
                SizedBox(width: 10),
                Text('Use automatic detection'),
              ],
            ),
          ),
      ],
    );
    if (choice == 'fiducial') {
      ref.read(projectProvider.notifier).setFiducial(record.id, true);
    } else if (choice == 'component') {
      ref.read(projectProvider.notifier).setFiducial(record.id, false);
    } else if (choice == 'automatic') {
      ref
          .read(projectProvider.notifier)
          .useAutomaticFiducialDetection(record.id);
    }
  }

  Widget _chip(
    BuildContext ctx,
    String text,
    bool dimmed,
    bool fiducial,
    ColorScheme colors,
  ) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    Color bg = dimmed
        ? colors.surfaceContainerHighest.withValues(alpha: 0.55)
        : (isDark ? const Color(0xFF3A2D2D) : const Color(0xFFFFFBFA));
    Color fg = dimmed
        ? colors.onSurfaceVariant.withValues(alpha: 0.65)
        : (isDark ? const Color(0xFFFFE3E3) : const Color(0xFF500000));
    Color border = isDark ? const Color(0xFF765858) : const Color(0xFFE5CACA);
    if (fiducial && !dimmed) {
      bg = Colors.teal.withValues(alpha: 0.18);
      fg = isDark ? Colors.teal.shade100 : Colors.teal.shade800;
      border = Colors.teal.withValues(alpha: 0.40);
    }
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PlacementRecord rec,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove component?'),
        content: Text(
          'Remove ${rec.designator} (${rec.value}) from the project?\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(projectProvider.notifier).deleteRecord(rec.id);
    }
  }
}

// ── Inline feeder field ───────────────────────────────────────────────────────
class _InlineField extends StatefulWidget {
  final String value, hint;
  final bool isInt, isDuplicate;
  final ValueChanged<String> onChanged;
  const _InlineField({
    required this.value,
    required this.hint,
    required this.onChanged,
    this.isInt = false,
    this.isDuplicate = false,
  });
  @override
  State<_InlineField> createState() => _InlineFieldState();
}

class _InlineFieldState extends State<_InlineField> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_InlineField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            widget.isInt ? RegExp(r'\d') : RegExp(r'[\d.]'),
          ),
        ],
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: widget.isDuplicate ? colors.error : null,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 6,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(
              color: widget.isDuplicate ? colors.error : colors.outline,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(
              color: widget.isDuplicate ? colors.error : colors.outline,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

// ── Double-click editable cell ────────────────────────────────────────────────
class _EditableCell extends StatefulWidget {
  final String value, suffix;
  final bool isInt;
  final ValueChanged<String> onSave;
  const _EditableCell({
    required this.value,
    required this.suffix,
    required this.onSave,
    this.isInt = false,
  });
  @override
  State<_EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<_EditableCell> {
  bool _editing = false;
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
    _focus = FocusNode()
      ..addListener(() {
        if (!_focus.hasFocus && _editing) _commit();
      });
  }

  @override
  void didUpdateWidget(_EditableCell old) {
    super.didUpdateWidget(old);
    if (!_editing && old.value != widget.value) _ctrl.text = widget.value;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    widget.onSave(_ctrl.text.trim());
    setState(() => _editing = false);
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _ctrl.text = widget.value;
    });
    Future.microtask(() => _focus.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          keyboardType: widget.isInt
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              widget.isInt ? RegExp(r'\d') : RegExp(r'[\d.]'),
            ),
          ],
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 6,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
          ),
          onSubmitted: (_) => _commit(),
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: _startEditing,
      child: Tooltip(
        message: 'Double-click to edit',
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              '${widget.value} ${widget.suffix}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Export bar ────────────────────────────────────────────────────────────────
class _ExportBar extends ConsumerWidget {
  final ProjectValidationState validation;
  const _ExportBar({required this.validation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final canExport = validation.canExport;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              canExport
                  ? 'All feeder slots assigned — ready to export'
                  : (validation.blockingErrors.isNotEmpty
                        ? validation.blockingErrors.first
                        : 'Assign feeder slots to all enabled components'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: canExport
                    ? Colors.green.shade700
                    : colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: canExport
                ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ExportPreviewScreen(),
                    ),
                  )
                : null,
            icon: const Icon(Icons.preview_rounded),
            label: const Text('Preview & Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: canExport
                  ? Colors.green
                  : colors.surfaceContainerHighest,
              foregroundColor: canExport
                  ? Colors.white
                  : colors.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
