import 'package:uuid/uuid.dart';

import '../models/tabular_document.dart';
import '../models/resolved_schema.dart';
import '../models/placement_record.dart';
import '../models/board_side.dart';

const _uuid = Uuid();

/// Pure, deterministic row-to-record transformer.
/// Given identical inputs it always produces identical PlacementRecord outputs.
class NormalizationService {
  const NormalizationService._();

  static List<PlacementRecord> normalizeRows(
    TabularDocument doc,
    ResolvedSchema schema,
  ) {
    final records = <PlacementRecord>[];
    final headerList = doc.originalHeaders;

    for (final row in doc.rows) {
      final rawCells = [for (int i = 0; i < doc.columnCount; i++) row[i]];
      final warnings = <String>[];

      // ── Designator ──────────────────────────────────────────────────────────
      final designator = _cell(row, schema[CanonicalField.designator]);
      if (designator.isEmpty) {
        warnings.add('Row ${row.originalLineIndex + 1}: empty designator');
      }

      // ── X / Y ───────────────────────────────────────────────────────────────
      final xRaw = _cell(row, schema[CanonicalField.x]);
      final yRaw = _cell(row, schema[CanonicalField.y]);
      final xMm = _parseCoord(xRaw);
      final yMm = _parseCoord(yRaw);
      if (xMm == null) {
        warnings.add('Row ${row.originalLineIndex + 1}: cannot parse X="$xRaw"');
      }
      if (yMm == null) {
        warnings.add('Row ${row.originalLineIndex + 1}: cannot parse Y="$yRaw"');
      }
      if (xMm == null || yMm == null) continue; // skip unparseable rows

      // ── Rotation ────────────────────────────────────────────────────────────
      final rotRaw = _cell(row, schema[CanonicalField.rotation]);
      double rotDeg = double.tryParse(rotRaw) ?? 0.0;
      rotDeg = ((rotDeg % 360) + 360) % 360; // normalise to 0–360

      // ── Side ────────────────────────────────────────────────────────────────
      final sideRaw = _cell(row, schema[CanonicalField.side]);
      final side = sideRaw.isEmpty
          ? BoardSide.top // default assumption
          : BoardSide.fromString(sideRaw);
      if (side == BoardSide.unknown) {
        warnings.add('Row ${row.originalLineIndex + 1}: unrecognised side "$sideRaw"; '
            'side-filtering may be inaccurate');
      }

      // ── Value / Footprint ───────────────────────────────────────────────────
      final value = _sanitizeText(_cell(row, schema[CanonicalField.value]));
      final footprint = _sanitizeText(_cell(row, schema[CanonicalField.footprint]));

      records.add(PlacementRecord(
        id: _uuid.v4(),
        designator: designator,
        value: value,
        footprint: footprint,
        xMm: xMm,
        yMm: yMm,
        rotationDeg: rotDeg,
        side: side,
        sourceRowIndex: row.originalLineIndex,
        sourceHeaders: List.unmodifiable(headerList),
        rawRow: List.unmodifiable(rawCells),
        warnings: List.unmodifiable(warnings),
      ));
    }

    return records;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _cell(TabularRow row, int colIndex) =>
      colIndex >= 0 ? row[colIndex] : '';

  /// Parse coordinate – strips trailing "mm" or whitespace.
  static double? _parseCoord(String raw) {
    final cleaned = raw
        .toLowerCase()
        .replaceAll('mm', '')
        .replaceAll(' ', '')
        .trim();
    return double.tryParse(cleaned);
  }

  static String _sanitizeText(String s) =>
      s.replaceAll(RegExp(r'[\x00-\x1F]'), '').trim();
}
