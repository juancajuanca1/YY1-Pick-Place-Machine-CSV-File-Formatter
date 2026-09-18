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
    final descriptionIndex = _findHeaderIndex(doc, const ['description']);
    final valueHeader = _headerAt(doc, schema[CanonicalField.value]);
    final useDescriptionValueFallback =
        valueHeader == 'comment' && descriptionIndex >= 0;

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
        warnings.add(
          'Row ${row.originalLineIndex + 1}: cannot parse X="$xRaw"',
        );
      }
      if (yMm == null) {
        warnings.add(
          'Row ${row.originalLineIndex + 1}: cannot parse Y="$yRaw"',
        );
      }
      if (xMm == null || yMm == null) continue; // skip unparseable rows

      // ── Rotation ────────────────────────────────────────────────────────────
      final rotRaw = _cell(row, schema[CanonicalField.rotation]);
      double rotDeg = double.tryParse(rotRaw) ?? 0.0;
      rotDeg = ((rotDeg % 360) + 360) % 360; // normalise to 0–360

      // ── Side ────────────────────────────────────────────────────────────────
      final sideRaw = _cell(row, schema[CanonicalField.side]);
      final side = sideRaw.isEmpty
          ? (doc.inferredSide == BoardSide.unknown
                ? BoardSide.top
                : doc.inferredSide)
          : BoardSide.fromString(sideRaw);
      if (side == BoardSide.unknown) {
        warnings.add(
          'Row ${row.originalLineIndex + 1}: unrecognised side "$sideRaw"; '
          'side-filtering may be inaccurate',
        );
      }

      // ── Value / Footprint ───────────────────────────────────────────────────
      final rawValue = _sanitizeText(_cell(row, schema[CanonicalField.value]));
      final rawFootprint = _sanitizeText(
        _cell(row, schema[CanonicalField.footprint]),
      );
      final description = descriptionIndex >= 0
          ? _sanitizeText(_cell(row, descriptionIndex))
          : '';
      final normalizedIdentity = _normalizeIdentity(
        rawValue: rawValue,
        rawFootprint: rawFootprint,
        description: description,
        useDescriptionValueFallback: useDescriptionValueFallback,
      );
      final value = normalizedIdentity.value;
      final footprint = normalizedIdentity.footprint;

      records.add(
        PlacementRecord(
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
        ),
      );
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

  static int _findHeaderIndex(TabularDocument doc, List<String> headers) {
    for (int i = 0; i < doc.headers.length; i++) {
      if (headers.contains(doc.headers[i])) return i;
    }
    return -1;
  }

  static String _headerAt(TabularDocument doc, int colIndex) {
    if (colIndex < 0 || colIndex >= doc.headers.length) return '';
    return doc.headers[colIndex];
  }

  static ({String value, String footprint}) _normalizeIdentity({
    required String rawValue,
    required String rawFootprint,
    required String description,
    required bool useDescriptionValueFallback,
  }) {
    if (!useDescriptionValueFallback || description.isEmpty) {
      return (value: rawValue, footprint: rawFootprint);
    }

    final extractedValue = _extractPassiveValue(description);
    if (extractedValue == null) {
      return (value: rawValue, footprint: rawFootprint);
    }

    final extractedPackage = _extractPackage(description);
    return (
      value: extractedValue,
      footprint: extractedPackage ?? rawFootprint,
    );
  }

  static String? _extractPassiveValue(String rawDescription) {
    final description = rawDescription.replaceAll(RegExp(r'[µμ]'), 'u');

    final resistor = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*([kmg]?)\s*ohm\b',
      caseSensitive: false,
    ).firstMatch(description);
    if (resistor != null) {
      final magnitude = resistor.group(1)!;
      final prefix = (resistor.group(2) ?? '').toUpperCase();
      return prefix.isEmpty ? '${magnitude}R' : '$magnitude$prefix';
    }

    final capacitor = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*([pnum]?)f\b',
      caseSensitive: false,
    ).firstMatch(description);
    if (capacitor != null) {
      final magnitude = capacitor.group(1)!;
      final prefix = (capacitor.group(2) ?? '').toLowerCase();
      return '$magnitude${prefix}F';
    }

    final inductor = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*([pnum]?)h\b',
      caseSensitive: false,
    ).firstMatch(description);
    if (inductor != null) {
      final magnitude = inductor.group(1)!;
      final prefix = (inductor.group(2) ?? '').toLowerCase();
      return '$magnitude${prefix}H';
    }

    return null;
  }

  static String? _extractPackage(String description) {
    final passiveSize = RegExp(
      r'\b(01005|0201|0402|0603|0805|1206|1210|1812|2010|2512)\b',
      caseSensitive: false,
    ).firstMatch(description);
    if (passiveSize != null) {
      return passiveSize.group(1)!.toUpperCase();
    }
    return null;
  }
}
