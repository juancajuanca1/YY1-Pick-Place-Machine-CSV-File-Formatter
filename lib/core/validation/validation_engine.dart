import '../models/placement_project.dart';
import '../models/board_side.dart';

/// Pure validation. Never mutates state – only reads and computes.
class ValidationEngine {
  const ValidationEngine._();

  static ProjectValidationState evaluate(PlacementProject? project) {
    if (project == null) {
      return ProjectValidationState.empty.copyWith(
        blockingErrors: ['No project loaded.'],
      );
    }

    final errors = <String>[];
    final warnings = <String>[];

    final sideRecords = project.records
        .where((r) => r.enabled && r.side == project.exportSide)
        .toList();

    // At least one exportable row
    final hasRow = sideRecords.isNotEmpty;
    if (!hasRow) {
      errors.add(
          'No enabled components found on the ${project.exportSide.label} side.');
    }

    // All enabled rows on the selected side must have a slot
    // (fiducials are exempt – they never need a feeder slot)
    final missingSlots =
        sideRecords.where((r) => r.feederSlot == null && !r.isFiducial).length;
    final allHaveSlots = missingSlots == 0;
    if (!allHaveSlots) {
      errors.add('$missingSlots component(s) are missing feeder slot assignments.');
    }

    // Duplicate slot check
    final dupes = project.duplicateSlots;
    final noDupes = dupes.isEmpty;
    if (!noDupes) {
      warnings.add(
          'Slot(s) ${dupes.join(', ')} are assigned to incompatible component groups.');
    }

    // Warn about unknown-side rows
    final unknownCount =
        project.records.where((r) => r.side == BoardSide.unknown).length;
    if (unknownCount > 0) {
      warnings.add('$unknownCount record(s) have an unrecognised side and are excluded.');
    }

    // Warn about component warnings from normalization
    final recWarnings =
        project.records.expand((r) => r.warnings).toSet();
    if (recWarnings.isNotEmpty) {
      warnings.addAll(recWarnings.take(5));
      if (recWarnings.length > 5) {
        warnings.add('… and ${recWarnings.length - 5} more normalisation warning(s).');
      }
    }

    return ProjectValidationState(
      hasResolvedSchema: true,
      hasAtLeastOneExportableRow: hasRow,
      allEnabledRowsHaveSlots: allHaveSlots,
      hasNoDuplicateSlots: noDupes,
      blockingErrors: List.unmodifiable(errors),
      warnings: List.unmodifiable(warnings),
    );
  }
}

extension _VsCopy on ProjectValidationState {
  ProjectValidationState copyWith({List<String>? blockingErrors}) {
    return ProjectValidationState(
      hasResolvedSchema: hasResolvedSchema,
      hasAtLeastOneExportableRow: hasAtLeastOneExportableRow,
      allEnabledRowsHaveSlots: allEnabledRowsHaveSlots,
      hasNoDuplicateSlots: hasNoDuplicateSlots,
      blockingErrors: blockingErrors ?? this.blockingErrors,
      warnings: warnings,
    );
  }
}
