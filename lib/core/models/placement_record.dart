import 'board_side.dart';

/// The canonical record every import path must produce before UI or export.
class PlacementRecord {
  final String id;

  // Core placement fields
  final String designator;
  final String value;
  final String footprint;
  final double xMm;
  final double yMm;
  final double rotationDeg;
  final BoardSide side;

  // User-assigned (post-import)
  final int? feederSlot;
  final int? nozzleClass;
  final bool enabled;

  /// null uses automatic name/package detection; true/false is a user choice.
  final bool? fiducialOverride;

  // Machine parameters (editable per-record)
  final int mountSpeed; // percent, default 100
  final double pickHeight; // mm, default 0.0
  final double placeHeight; // mm, default 0.0
  // Provenance – for tracing back to source rows
  final int sourceRowIndex;
  final List<String> sourceHeaders;
  final List<String> rawRow;

  // Diagnostics
  final List<String> warnings;

  const PlacementRecord({
    required this.id,
    required this.designator,
    required this.value,
    required this.footprint,
    required this.xMm,
    required this.yMm,
    required this.rotationDeg,
    required this.side,
    this.feederSlot,
    this.nozzleClass,
    this.enabled = true,
    this.fiducialOverride,
    this.mountSpeed = 100,
    this.pickHeight = 0.0,
    this.placeHeight = 0.0,
    required this.sourceRowIndex,
    required this.sourceHeaders,
    required this.rawRow,
    this.warnings = const [],
  });

  /// Cluster key: identical value + footprint + side form one assignment group.
  String get groupKey =>
      '${value.trim().toLowerCase()}|${footprint.trim().toLowerCase()}|${side.name}';

  /// True when this component is a fiducial mark (never needs a feeder slot).
  bool get isFiducial {
    if (fiducialOverride != null) return fiducialOverride!;
    final ref = designator.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (RegExp(r'^(?:fd|fid|fed|fduc|feduc|fud)\d*$').hasMatch(ref)) {
      return true;
    }

    String normalized(String input) =>
        input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    final normalizedValue = normalized(value);
    final normalizedFootprint = normalized(footprint);
    if ({'fd', 'fed'}.contains(normalizedValue) ||
        {'fd', 'fed'}.contains(normalizedFootprint)) {
      return true;
    }
    final check = '$normalizedValue $normalizedFootprint';
    final compact = check.replaceAll(' ', '');
    if (compact.contains('registrationmark') ||
        compact.contains('toolingmark')) {
      return true;
    }
    return RegExp(
      r'(^| )(?:fid|fiduc|feduc|fiducial|feducial|fidmark|fiducialmark)( |$)',
    ).hasMatch(check);
  }

  bool get isExportReady =>
      enabled && feederSlot != null && side != BoardSide.unknown;

  PlacementRecord copyWith({
    String? designator,
    String? value,
    String? footprint,
    double? xMm,
    double? yMm,
    double? rotationDeg,
    BoardSide? side,
    int? feederSlot,
    int? nozzleClass,
    bool? enabled,
    bool? fiducialOverride,
    int? mountSpeed,
    double? pickHeight,
    double? placeHeight,
    List<String>? warnings,
    bool clearFeederSlot = false,
    bool clearNozzleClass = false,
    bool clearFiducialOverride = false,
  }) {
    return PlacementRecord(
      id: id,
      designator: designator ?? this.designator,
      value: value ?? this.value,
      footprint: footprint ?? this.footprint,
      xMm: xMm ?? this.xMm,
      yMm: yMm ?? this.yMm,
      rotationDeg: rotationDeg ?? this.rotationDeg,
      side: side ?? this.side,
      feederSlot: clearFeederSlot ? null : (feederSlot ?? this.feederSlot),
      nozzleClass: clearNozzleClass ? null : (nozzleClass ?? this.nozzleClass),
      enabled: enabled ?? this.enabled,
      fiducialOverride: clearFiducialOverride
          ? null
          : (fiducialOverride ?? this.fiducialOverride),
      mountSpeed: mountSpeed ?? this.mountSpeed,
      pickHeight: pickHeight ?? this.pickHeight,
      placeHeight: placeHeight ?? this.placeHeight,
      sourceRowIndex: sourceRowIndex,
      sourceHeaders: sourceHeaders,
      rawRow: rawRow,
      warnings: warnings ?? this.warnings,
    );
  }
}
