/// Canonical fields the import contract requires.
enum CanonicalField {
  designator, // required
  x, // required
  y, // required
  rotation, // required
  side, // required
  value, // recommended
  footprint, // recommended
}

extension CanonicalFieldExt on CanonicalField {
  bool get isRequired => switch (this) {
    CanonicalField.designator ||
    CanonicalField.x ||
    CanonicalField.y ||
    CanonicalField.rotation => true,
    _ => false,
  };

  String get label => switch (this) {
    CanonicalField.designator => 'Designator',
    CanonicalField.x => 'X Coordinate',
    CanonicalField.y => 'Y Coordinate',
    CanonicalField.rotation => 'Rotation',
    CanonicalField.side => 'Side / Layer',
    CanonicalField.value => 'Component Value',
    CanonicalField.footprint => 'Footprint',
  };
}

/// A scored candidate for a single canonical field.
class FieldCandidate {
  final int columnIndex;
  final String headerName;
  final double score; // 0.0 – 1.0
  final String reason;

  const FieldCandidate({
    required this.columnIndex,
    required this.headerName,
    required this.score,
    required this.reason,
  });
}

/// Full inference result from FieldInferenceService.
class SchemaMatchResult {
  /// Best mapping: canonical field → resolved column index (or -1 if not found).
  final Map<CanonicalField, int> resolvedColumns;

  /// All scored candidates per field (sorted best-first).
  final Map<CanonicalField, List<FieldCandidate>> candidates;

  /// Per-field confidence (0.0 – 1.0), taken from the top candidate.
  final Map<CanonicalField, double> confidence;

  /// Fields that could not be resolved at all.
  final List<CanonicalField> unresolvedRequired;

  /// Human-readable diagnostics shown in the review panel.
  final List<String> diagnostics;

  const SchemaMatchResult({
    required this.resolvedColumns,
    required this.candidates,
    required this.confidence,
    required this.unresolvedRequired,
    required this.diagnostics,
  });

  /// True when all required fields have been mapped with confidence ≥ threshold.
  bool get isHighConfidence {
    const threshold = 0.70;
    if (unresolvedRequired.isNotEmpty) return false;
    for (final f in CanonicalField.values.where((f) => f.isRequired)) {
      if ((confidence[f] ?? 0.0) < threshold) return false;
    }
    return true;
  }

  int columnFor(CanonicalField f) => resolvedColumns[f] ?? -1;
}

/// User-confirmed (or auto-accepted) field→column mapping.
class ResolvedSchema {
  final Map<CanonicalField, int> columns;
  final bool userConfirmed;

  const ResolvedSchema({required this.columns, required this.userConfirmed});

  int operator [](CanonicalField f) => columns[f] ?? -1;
}
