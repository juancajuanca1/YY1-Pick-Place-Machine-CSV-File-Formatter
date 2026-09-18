import 'package:flutter_test/flutter_test.dart';

import 'package:neoden_yy1_formatter/core/models/board_side.dart';
import 'package:neoden_yy1_formatter/core/models/placement_record.dart';
import 'package:neoden_yy1_formatter/features/providers.dart';

void main() {
  test('first feeder slot assignment propagates exact value to unassigned group', () {
    final notifier = ProjectNotifier();
    notifier.load([
      _record(id: 'r1', designator: 'R1'),
      _record(id: 'r2', designator: 'R2'),
    ], 'board.csv');

    notifier.setFeederSlot('r1', 30);

    final project = notifier.state!;
    expect(project.records.first.feederSlot, 30);
    expect(project.records.last.feederSlot, 30);
  });

  test('first feeder slot assignment propagates to matching bottom-side records', () {
    final notifier = ProjectNotifier();
    notifier.load([
      _record(id: 't1', designator: 'R1', side: BoardSide.top),
      _record(id: 'b1', designator: 'R101', side: BoardSide.bottom),
    ], 'board.csv');

    notifier.setFeederSlot('t1', 30);

    final project = notifier.state!;
    expect(project.records[0].feederSlot, 30);
    expect(project.records[1].feederSlot, 30);
  });

  test('later feeder slot edits only change the targeted component', () {
    final notifier = ProjectNotifier();
    notifier.load([
      _record(id: 'r1', designator: 'R1'),
      _record(id: 'r2', designator: 'R2'),
    ], 'board.csv');

    notifier.setFeederSlot('r1', 30);
    notifier.setFeederSlot('r1', 3);

    final project = notifier.state!;
    expect(project.records.first.feederSlot, 3);
    expect(project.records.last.feederSlot, 30);
  });

  test('same slot on top and bottom does not count as duplicate for same part', () {
    final notifier = ProjectNotifier();
    notifier.load([
      _record(id: 't1', designator: 'R1', side: BoardSide.top),
      _record(id: 'b1', designator: 'R101', side: BoardSide.bottom),
      _record(
        id: 'c1',
        designator: 'C1',
        side: BoardSide.top,
        value: '100nF',
        footprint: '0402',
      ),
    ], 'board.csv');

    notifier.setFeederSlot('t1', 30);
    notifier.setFeederSlot('c1', 30);

    expect(notifier.state!.duplicateSlots, [30]);
  });
}

PlacementRecord _record({
  required String id,
  required String designator,
  BoardSide side = BoardSide.top,
  String value = '10k',
  String footprint = '0402',
}) {
  return PlacementRecord(
    id: id,
    designator: designator,
    value: value,
    footprint: footprint,
    xMm: 1,
    yMm: 2,
    rotationDeg: 0,
    side: side,
    sourceRowIndex: 0,
    sourceHeaders: const ['Designator'],
    rawRow: const ['R1'],
  );
}