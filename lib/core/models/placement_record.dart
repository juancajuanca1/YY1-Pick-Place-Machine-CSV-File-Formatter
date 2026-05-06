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

  // Machine parameters (editable per-record)
  final int mountSpeed;   // percent, default 100
  final double pickHeight;  // mm, default 0.0
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
    final check = '${designator.toLowerCase()} ${value.toLowerCase()} ${footprint.toLowerCase()}';
    return check.contains('fiducial') || check.contains('feducial') || check.contains('fiduc');
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
    int? mountSpeed,
    double? pickHeight,
    double? placeHeight,
    List<String>? warnings,
    bool clearFeederSlot = false,
    bool clearNozzleClass = false,
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
