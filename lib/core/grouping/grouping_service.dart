import '../models/placement_record.dart';
import '../models/placement_project.dart';

/// Clusters PlacementRecords into AssignmentGroups by (value, footprint, side).
class GroupingService {
  const GroupingService._();

  static List<AssignmentGroup> buildGroups(List<PlacementRecord> records) {
    final orderMap = <String, int>{};
    final groupMap = <String, List<PlacementRecord>>{};

    for (final r in records) {
      if (!groupMap.containsKey(r.groupKey)) {
        orderMap[r.groupKey] = orderMap.length;
        groupMap[r.groupKey] = [];
      }
      groupMap[r.groupKey]!.add(r);
    }

    final groups =
        groupMap.entries.map((e) {
          final first = e.value.first;
          return AssignmentGroup(
            groupKey: e.key,
            displayValue: first.value.isEmpty ? '(no value)' : first.value,
            displayFootprint: first.footprint.isEmpty
                ? '(no footprint)'
                : first.footprint,
            side: first.side,
            records: List.unmodifiable(e.value),
          );
        }).toList()..sort(
          (a, b) => orderMap[a.groupKey]!.compareTo(orderMap[b.groupKey]!),
        );

    return groups;
  }
}
