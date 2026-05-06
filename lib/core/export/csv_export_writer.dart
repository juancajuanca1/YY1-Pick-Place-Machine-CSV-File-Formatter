import '../models/placement_project.dart';
import '../models/board_side.dart';
import 'machine_export_profile.dart';

class ExportValidationReport {
  final List<String> issues;
  bool get isValid => issues.isEmpty;
  const ExportValidationReport({required this.issues});
}

class CsvExportWriter {
  final MachineExportProfile profile;

  const CsvExportWriter({this.profile = const Yy1ImportProfile()});

  /// Serialises the project into a complete CSV string.
  String write(
    PlacementProject project, {
    BoardSide sideFilter = BoardSide.top,
  }) {
    final buf = StringBuffer();

    // Machine-required preamble (NEODEN header, PanelizedPCB, Fiducial,
    // NozzleChange rows, etc.)
    buf.write(profile.preamble());

    // Column header row
    buf.write(
        profile.headerColumns.join(profile.delimiter) + profile.lineEnding);

    // Rows: filter → sort by slot then designator
    final rows = project.records
        .where((r) =>
            r.enabled &&
            !r.isFiducial &&
            (sideFilter == BoardSide.unknown || r.side == sideFilter) &&
            r.feederSlot != null)
        .toList()
      ..sort((a, b) {
        final slotCmp = (a.feederSlot ?? 0).compareTo(b.feederSlot ?? 0);
        return slotCmp != 0 ? slotCmp : a.designator.compareTo(b.designator);
      });

    for (final r in rows) {
      buf.write(profile.serializeRow(profile.rowFields(r)) + profile.lineEnding);
    }

    return buf.toString();
  }

  /// Post-write verifier: finds the header row (the line that starts with
  /// "Designator") and validates data rows below it.
  ExportValidationReport validate(String csvContent) {
    final issues = <String>[];
    final allLines = csvContent.split(RegExp(r'\r?\n'));

    // Find where the Designator header row is
    final headerIdx = allLines
        .indexWhere((l) => l.trim().startsWith('Designator'));

    if (headerIdx < 0) {
      issues.add('Export is missing the Designator column header row.');
      return ExportValidationReport(issues: issues);
    }

    final dataLines = allLines
        .skip(headerIdx + 1)
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (dataLines.isEmpty) {
      issues.add('Export contains no placement data rows.');
      return ExportValidationReport(issues: issues);
    }

    final expectedCols = profile.headerColumns.length;

    for (int i = 0; i < dataLines.length; i++) {
      final parts = dataLines[i].split(profile.delimiter);
      if (parts.length != expectedCols) {
        issues.add(
            'Data row ${i + 1}: ${parts.length} columns (expected $expectedCols).');
      }
      // Numeric checks: Mid X(3), Mid Y(4), Rotation(5), FeederNo(7)
      for (final ci in [3, 4, 5, 7]) {
        if (ci < parts.length && double.tryParse(parts[ci].trim()) == null) {
          issues.add(
              'Data row ${i + 1}: non-numeric in column ${ci + 1}: "${parts[ci].trim()}"');
        }
      }
    }

    return ExportValidationReport(issues: issues);
  }
}
