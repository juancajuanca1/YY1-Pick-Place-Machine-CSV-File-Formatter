import 'placement_record.dart';
import 'board_side.dart';

/// Holds all normalized records plus the user's feeder-assignment decisions.
class PlacementProject {
  final String sourceFileName;
  final List<PlacementRecord> records;
  final BoardSide exportSide;

  const PlacementProject({
    required this.sourceFileName,
    required this.records,
    this.exportSide = BoardSide.top,
  });

  PlacementProject copyWith({
    List<PlacementRecord>? records,
    BoardSide? exportSide,
  }) {
    return PlacementProject(
      sourceFileName: sourceFileName,
      records: records ?? this.records,
      exportSide: exportSide ?? this.exportSide,
    );
  }

  List<PlacementRecord> get exportableRecords =>
      records.where((r) => r.isExportReady && r.side == exportSide).toList();

  bool get hasTopRecords => records.any((r) => r.side == BoardSide.top);

  bool get hasBottomRecords => records.any((r) => r.side == BoardSide.bottom);

  /// All unique slot numbers assigned across incompatible group keys.
  List<int> get duplicateSlots {
    final slotToGroup = <int, String>{};
    final dupes = <int>{};
    for (final r in records) {
      if (r.feederSlot == null) continue;
      final existing = slotToGroup[r.feederSlot!];
      if (existing != null && existing != r.assignmentKey) {
        dupes.add(r.feederSlot!);
      } else {
        slotToGroup[r.feederSlot!] = r.assignmentKey;
      }
    }
    return dupes.toList();
  }
}

/// Derived, computed-only object. Never mutated directly.
class ProjectValidationState {
  final bool hasResolvedSchema;
  final bool hasAtLeastOneExportableRow;
  final bool allEnabledRowsHaveSlots;
  final bool hasNoDuplicateSlots;
  final List<String> blockingErrors;
  final List<String> warnings;

  const ProjectValidationState({
    required this.hasResolvedSchema,
    required this.hasAtLeastOneExportableRow,
    required this.allEnabledRowsHaveSlots,
    required this.hasNoDuplicateSlots,
    required this.blockingErrors,
    required this.warnings,
  });

  bool get canExport =>
      hasResolvedSchema &&
      hasAtLeastOneExportableRow &&
      allEnabledRowsHaveSlots &&
      blockingErrors.isEmpty;

  static const empty = ProjectValidationState(
    hasResolvedSchema: false,
    hasAtLeastOneExportableRow: false,
    allEnabledRowsHaveSlots: false,
    hasNoDuplicateSlots: true,
    blockingErrors: [],
    warnings: [],
  );
}

/// One assignment group – all records sharing the same groupKey.
class AssignmentGroup {
  final String groupKey;
  final String displayValue;
  final String displayFootprint;
  final BoardSide side;
  final List<PlacementRecord> records;

  const AssignmentGroup({
    required this.groupKey,
    required this.displayValue,
    required this.displayFootprint,
    required this.side,
    required this.records,
  });

  int? get resolvedSlot {
    final slots = records.map((r) => r.feederSlot).toSet();
    return slots.length == 1 ? slots.first : null;
  }

  bool get allHaveSlots => records.every((r) => r.feederSlot != null);
}
