import '../models/tabular_document.dart';
import '../models/resolved_schema.dart';

import 'dart:math' as math;

/// Aliases for each canonical field – used for header-name scoring.
const _aliases = <CanonicalField, List<String>>{
  CanonicalField.designator: [
    'designator',
    'ref',
    'reference',
    'refdes',
    'ref des',
    'component',
    'part ref',
    'reference designator',
    'cmp',
  ],
  CanonicalField.x: [
    'x',
    'mid x',
    'x(mm)',
    'mid x(mm)',
    'posx',
    'center x',
    'x_mm',
    'mid_x',
    'pos x',
    'x coordinate',
    'x-pos',
  ],
  CanonicalField.y: [
    'y',
    'mid y',
    'y(mm)',
    'mid y(mm)',
    'posy',
    'center y',
    'y_mm',
    'mid_y',
    'pos y',
    'y coordinate',
    'y-pos',
  ],
  CanonicalField.rotation: [
    'rotation',
    'rot',
    'angle',
    'orientation',
    'rotate',
    'theta',
    'ang',
  ],
  CanonicalField.side: [
    'layer',
    'side',
    'tb',
    'top/bottom',
    'board side',
    'pcb layer',
    'placement side',
    'top bottom',
    'layers',
  ],
  CanonicalField.value: [
    'value',
    'val',
    'comment',
    'part value',
    'component value',
    'description',
    'part',
    'name',
  ],
  CanonicalField.footprint: [
    'footprint',
    'package',
    'package_reference',
    'package ref',
    'fp',
    'component package',
    'case',
    'enclosure',
  ],
};

/// Value-shape validators for semantic scoring.
final _numeric = RegExp(r'^-?\d+(\.\d+)?$');
final _sideValues = {
  'top',
  'toplayer',
  'top layer',
  't',
  'bottom',
  'bottomlayer',
  'bottom layer',
  'bot',
  'b',
  'f',
  'r',
  'f.cu',
  'b.cu',
  '1',
  '2',
  'front',
  'back',
};
final _designatorPattern = RegExp(r'^[A-Za-z]{1,4}\d+');

class FieldInferenceService {
  /// Entry point: score every column against every canonical field.
  static SchemaMatchResult inferSchema(TabularDocument doc) {
    if (doc.columnCount == 0) {
      return SchemaMatchResult(
        resolvedColumns: {},
        candidates: {},
        confidence: {},
        unresolvedRequired: CanonicalField.values
            .where((f) => f.isRequired)
            .toList(),
        diagnostics: ['File has no columns.'],
      );
    }

    final allCandidates = <CanonicalField, List<FieldCandidate>>{};
    for (final field in CanonicalField.values) {
      final scored = <FieldCandidate>[];
      for (int ci = 0; ci < doc.columnCount; ci++) {
        final header = ci < doc.headers.length ? doc.headers[ci] : '';
        final samples = doc.sampleColumn(ci);
        final score = _scoreColumn(field, header, samples);
        if (score > 0.0) {
          scored.add(
            FieldCandidate(
              columnIndex: ci,
              headerName: ci < doc.originalHeaders.length
                  ? doc.originalHeaders[ci]
                  : header,
              score: score,
              reason: _reason(field, header, samples, score),
            ),
          );
        }
      }
      scored.sort((a, b) => b.score.compareTo(a.score));
      allCandidates[field] = scored;
    }

    // Resolve: greedily assign the best unused candidate per field. Canonical
    // fields represent distinct source columns; reusing one can incorrectly
    // turn a value such as "10uF" into both the value and package.
    final resolved = <CanonicalField, int>{};
    final usedCols = <int>{};
    final confidence = <CanonicalField, double>{};

    // Process in priority order
    for (final field in CanonicalField.values) {
      final cands = allCandidates[field] ?? [];
      FieldCandidate? chosen;
      for (final c in cands) {
        if (usedCols.contains(c.columnIndex)) continue;
        chosen = c;
        break;
      }
      if (chosen != null) {
        resolved[field] = chosen.columnIndex;
        confidence[field] = chosen.score;
        usedCols.add(chosen.columnIndex);
      }
    }

    // Determine unresolved required fields
    final unresolved = CanonicalField.values
        .where(
          (f) =>
              f.isRequired &&
              (resolved[f] == null || (confidence[f] ?? 0) < 0.30),
        )
        .toList();

    final diagnostics = _buildDiagnostics(
      resolved,
      confidence,
      doc.originalHeaders,
    );

    return SchemaMatchResult(
      resolvedColumns: resolved,
      candidates: allCandidates,
      confidence: confidence,
      unresolvedRequired: unresolved,
      diagnostics: diagnostics,
    );
  }

  static double _scoreColumn(
    CanonicalField field,
    String header,
    List<String> samples,
  ) {
    double score = 0.0;

    // ── Header alias matching ────────────────────────────────────────────────
    final aliases = _aliases[field] ?? [];
    final h = header.trim().toLowerCase();
    if (aliases.contains(h)) {
      score += 0.60;
    } else {
      // Partial / token match
      for (final alias in aliases) {
        if (h.contains(alias) || alias.contains(h)) {
          score += 0.30;
          break;
        }
      }
      // Fuzzy similarity fallback
      for (final alias in aliases) {
        final sim = _jaroWinkler(h, alias);
        if (sim > 0.88) {
          score = math.max(score, 0.25 * sim);
          break;
        }
      }
    }

    // ── Semantic / value-shape scoring ──────────────────────────────────────
    if (samples.isEmpty) return score;

    switch (field) {
      case CanonicalField.x:
      case CanonicalField.y:
        final numericFraction = _numericFraction(samples);
        score += numericFraction * 0.35;
        // Coordinate-like: has variety (not all-same)
        if (_hasVariety(samples)) score += 0.05;

      case CanonicalField.rotation:
        final numericFraction = _numericFraction(samples);
        score += numericFraction * 0.25;
        // Cluster check: rotations tend to be multiples of 45
        if (_rotationLike(samples)) score += 0.15;

      case CanonicalField.side:
        final sideFraction =
            samples.where((s) => _sideValues.contains(s.toLowerCase())).length /
            samples.length;
        score += sideFraction * 0.40;

      case CanonicalField.designator:
        final desFraction =
            samples.where((s) => _designatorPattern.hasMatch(s)).length /
            samples.length;
        score += desFraction * 0.40;

      case CanonicalField.value:
        // Values are short strings with mixed alpha-numeric
        final valFraction =
            samples.where((s) => s.isNotEmpty && s.length < 20).length /
            samples.length;
        score += valFraction * 0.15;

      case CanonicalField.footprint:
        // Footprints often contain underscores, colons, or package names
        final fpFraction =
            samples
                .where(
                  (s) => s.contains('_') || s.contains(':') || s.contains('-'),
                )
                .length /
            samples.length;
        score += fpFraction * 0.20;
    }

    return score.clamp(0.0, 1.0);
  }

  static double _numericFraction(List<String> samples) {
    if (samples.isEmpty) return 0.0;
    final numeric = samples
        .where((s) => _numeric.hasMatch(s.replaceAll('mm', '').trim()))
        .length;
    return numeric / samples.length;
  }

  static bool _hasVariety(List<String> samples) {
    return samples.toSet().length > (samples.length * 0.3).ceil();
  }

  static bool _rotationLike(List<String> samples) {
    int hits = 0;
    for (final s in samples) {
      final v = double.tryParse(s);
      if (v == null) continue;
      if (v % 45 == 0 || v % 90 == 0) hits++;
    }
    return samples.isNotEmpty && hits / samples.length > 0.5;
  }

  static String _reason(
    CanonicalField field,
    String header,
    List<String> samples,
    double score,
  ) {
    final aliases = _aliases[field] ?? [];
    final h = header.toLowerCase();
    if (aliases.contains(h)) return 'Exact header match "$header"';
    for (final a in aliases) {
      if (h.contains(a)) return 'Header "$header" contains alias "$a"';
    }
    if (score >= 0.5) {
      return 'Value-shape analysis (${(score * 100).toInt()}% confidence)';
    }
    return 'Partial match (${(score * 100).toInt()}% confidence)';
  }

  static List<String> _buildDiagnostics(
    Map<CanonicalField, int> resolved,
    Map<CanonicalField, double> confidence,
    List<String> originalHeaders,
  ) {
    final diags = <String>[];
    for (final field in CanonicalField.values) {
      final col = resolved[field];
      final conf = confidence[field] ?? 0.0;
      if (col == null) {
        if (field.isRequired) {
          diags.add('${field.label}: NOT FOUND (required)');
        } else {
          diags.add('${field.label}: not found (optional)');
        }
      } else {
        final hdr = col < originalHeaders.length
            ? originalHeaders[col]
            : 'col $col';
        final pct = (conf * 100).toInt();
        diags.add('${field.label}: detected from "$hdr" ($pct% confidence)');
      }
    }
    return diags;
  }

  /// Simple Jaro–Winkler similarity for fuzzy header matching.
  static double _jaroWinkler(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    final matchWindow = (math.max(s1.length, s2.length) / 2).floor() - 1;
    if (matchWindow < 0) return 0.0;

    final s1Matches = List<bool>.filled(s1.length, false);
    final s2Matches = List<bool>.filled(s2.length, false);
    int matches = 0;
    int transpositions = 0;

    for (int i = 0; i < s1.length; i++) {
      final start = math.max(0, i - matchWindow);
      final end = math.min(i + matchWindow + 1, s2.length);
      for (int j = start; j < end; j++) {
        if (s2Matches[j] || s1[i] != s2[j]) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    int k = 0;
    for (int i = 0; i < s1.length; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }

    final jaro =
        (matches / s1.length +
            matches / s2.length +
            (matches - transpositions / 2) / matches) /
        3;

    // Winkler prefix boost
    int prefix = 0;
    for (int i = 0; i < math.min(4, math.min(s1.length, s2.length)); i++) {
      if (s1[i] == s2[i]) {
        prefix++;
      } else {
        break;
      }
    }

    return jaro + prefix * 0.1 * (1 - jaro);
  }
}
