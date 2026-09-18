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
}

PlacementRecord _record({required String id, required String designator}) {
  return PlacementRecord(
    id: id,
    designator: designator,
    value: '10k',
    footprint: '0402',
    xMm: 1,
    yMm: 2,
    rotationDeg: 0,
    side: BoardSide.top,
    sourceRowIndex: 0,
    sourceHeaders: const ['Designator'],
    rawRow: const ['R1'],
  );
}