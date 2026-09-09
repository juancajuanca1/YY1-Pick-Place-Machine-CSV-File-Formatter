import 'package:flutter_test/flutter_test.dart';

import 'package:neoden_yy1_formatter/core/models/board_side.dart';
import 'package:neoden_yy1_formatter/core/models/placement_record.dart';

PlacementRecord record({
  String designator = 'R1',
  String value = '10K',
  String footprint = 'RESC3216X70',
  bool? override,
}) => PlacementRecord(
  id: 'id',
  designator: designator,
  value: value,
  footprint: footprint,
  xMm: 1,
  yMm: 2,
  rotationDeg: 0,
  side: BoardSide.top,
  fiducialOverride: override,
  sourceRowIndex: 0,
  sourceHeaders: const [],
  rawRow: const [],
);

void main() {
  test('recognizes common fiducial abbreviations and misspellings', () {
    expect(record(designator: 'FD1').isFiducial, isTrue);
    expect(record(designator: 'FID2').isFiducial, isTrue);
    expect(record(designator: 'FED3').isFiducial, isTrue);
    expect(record(value: 'FED').isFiducial, isTrue);
    expect(record(value: 'FEDUCIAL').isFiducial, isTrue);
    expect(record(footprint: 'FID_040').isFiducial, isTrue);
    expect(record(value: 'registration-mark').isFiducial, isTrue);
    expect(record(value: 'tooling mark').isFiducial, isTrue);
  });

  test('manual choice overrides automatic detection', () {
    expect(record(designator: 'FD1', override: false).isFiducial, isFalse);
    expect(record(designator: 'R1', override: true).isFiducial, isTrue);
  });

  test('ordinary parts are not mistaken for fiducials', () {
    expect(record(value: '10uF', footprint: '').isFiducial, isFalse);
    expect(record(value: 'amplifier').isFiducial, isFalse);
    expect(
      record(value: 'YLED1206R', footprint: 'LED1206-FD').isFiducial,
      isFalse,
    );
  });
}
