import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neoden_yy1_formatter/core/ingest/file_ingestor.dart';
import 'package:neoden_yy1_formatter/core/inference/field_inference_service.dart';
import 'package:neoden_yy1_formatter/core/models/tabular_document.dart';
import 'package:neoden_yy1_formatter/core/models/resolved_schema.dart';
import 'package:neoden_yy1_formatter/core/models/placement_record.dart';
import 'package:neoden_yy1_formatter/core/models/placement_project.dart';
import 'package:neoden_yy1_formatter/core/models/board_side.dart';
import 'package:neoden_yy1_formatter/core/validation/validation_engine.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Raw file state
// ══════════════════════════════════════════════════════════════════════════════

class RawFileState {
  final String? fileName;
  final String? content;
  final bool isLoading;
  final String? error;

  const RawFileState({
    this.fileName,
    this.content,
    this.isLoading = false,
    this.error,
  });

  RawFileState copyWith({
    String? fileName,
    String? content,
    bool? isLoading,
    String? error,
    bool clearContent = false,
    bool clearError = false,
  }) => RawFileState(
    fileName: fileName ?? this.fileName,
    content: clearContent ? null : (content ?? this.content),
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class RawFileNotifier extends StateNotifier<RawFileState> {
  RawFileNotifier() : super(const RawFileState());
  void setLoading(String name) =>
      state = RawFileState(fileName: name, isLoading: true);
  void setContent(String name, String content) =>
      state = RawFileState(fileName: name, content: content);
  void setError(String err) =>
      state = state.copyWith(isLoading: false, error: err);
  void reset() => state = const RawFileState();
}

final rawFileProvider = StateNotifierProvider<RawFileNotifier, RawFileState>(
  (_) => RawFileNotifier(),
);

// ══════════════════════════════════════════════════════════════════════════════
// TabularDocument – derived
// ══════════════════════════════════════════════════════════════════════════════

final tabularDocumentProvider = Provider<TabularDocument?>((ref) {
  final raw = ref.watch(rawFileProvider);
  if (raw.content == null || raw.fileName == null) return null;
  return FileIngestor.ingest(content: raw.content!, fileName: raw.fileName!);
});

// ══════════════════════════════════════════════════════════════════════════════
// Schema inference
// ══════════════════════════════════════════════════════════════════════════════

final schemaMatchProvider = Provider<SchemaMatchResult?>((ref) {
  final doc = ref.watch(tabularDocumentProvider);
  if (doc == null) return null;
  return FieldInferenceService.inferSchema(doc);
});

// ══════════════════════════════════════════════════════════════════════════════
// Resolved (user-confirmed) schema
// ══════════════════════════════════════════════════════════════════════════════

class ResolvedSchemaNotifier extends StateNotifier<ResolvedSchema?> {
  ResolvedSchemaNotifier() : super(null);
  void accept(SchemaMatchResult match) => state = ResolvedSchema(
    columns: Map.from(match.resolvedColumns),
    userConfirmed: false,
  );
  void confirm(Map<CanonicalField, int> userMapping) =>
      state = ResolvedSchema(columns: userMapping, userConfirmed: true);
  void reset() => state = null;
}

final resolvedSchemaProvider =
    StateNotifierProvider<ResolvedSchemaNotifier, ResolvedSchema?>(
      (_) => ResolvedSchemaNotifier(),
    );

// ══════════════════════════════════════════════════════════════════════════════
// Placement project (normalized records + user assignments)
// ══════════════════════════════════════════════════════════════════════════════

class ProjectNotifier extends StateNotifier<PlacementProject?> {
  ProjectNotifier() : super(null);

  void load(List<PlacementRecord> records, String fileName) {
    state = PlacementProject(sourceFileName: fileName, records: records);
  }

  /// Sets the feeder slot for the given record.
  /// Auto-fill behaviour:
  ///   - If other matching records still have NO slot assigned, the new value
  ///     is propagated to them automatically (first-time fill).
  ///   - Once a record already has a slot, later edits stay local to the
  ///     record being edited so each side/component can be changed later.
  void setFeederSlot(String id, int? slot) {
    final p = state;
    if (p == null) return;
    final target = p.records.where((r) => r.id == id).firstOrNull;
    if (target == null) return;
    final assignmentKey = target.assignmentKey;
    _update((r) {
      if (r.id == id) {
        // Always update the record that was directly edited
        return r.copyWith(feederSlot: slot, clearFeederSlot: slot == null);
      }
      if (r.assignmentKey == assignmentKey && r.feederSlot == null && slot != null) {
        // Propagate only to matching unassigned records across both sides.
        return r.copyWith(feederSlot: slot);
      }
      return r;
    });
  }

  void applySlotToGroup(String groupKey, int slot) =>
      _update((r) => r.groupKey == groupKey ? r.copyWith(feederSlot: slot) : r);

  void toggleEnabled(String id) =>
      _update((r) => r.id == id ? r.copyWith(enabled: !r.enabled) : r);

  void setFiducial(String id, bool value) => _update(
    (r) => r.id == id
        ? r.copyWith(fiducialOverride: value, clearFeederSlot: value)
        : r,
  );

  void useAutomaticFiducialDetection(String id) =>
      _update((r) => r.id == id ? r.copyWith(clearFiducialOverride: true) : r);

  void setMountSpeed(String id, int speed) =>
      _update((r) => r.id == id ? r.copyWith(mountSpeed: speed) : r);

  void setPickHeight(String id, double h) =>
      _update((r) => r.id == id ? r.copyWith(pickHeight: h) : r);

  void setPlaceHeight(String id, double h) =>
      _update((r) => r.id == id ? r.copyWith(placeHeight: h) : r);

  void applyGlobalSpeed(int speed) =>
      _update((r) => r.copyWith(mountSpeed: speed));

  void applyGlobalPickHeight(double h) =>
      _update((r) => r.copyWith(pickHeight: h));

  void applyGlobalPlaceHeight(double h) =>
      _update((r) => r.copyWith(placeHeight: h));

  void deleteRecord(String id) {
    final p = state;
    if (p == null) return;
    state = p.copyWith(records: p.records.where((r) => r.id != id).toList());
  }

  void setExportSide(BoardSide side) {
    final p = state;
    if (p == null) return;
    state = p.copyWith(exportSide: side);
  }

  void reset() => state = null;

  void _update(PlacementRecord Function(PlacementRecord) fn) {
    final p = state;
    if (p == null) return;
    state = p.copyWith(records: p.records.map(fn).toList());
  }
}

final projectProvider =
    StateNotifierProvider<ProjectNotifier, PlacementProject?>(
      (_) => ProjectNotifier(),
    );

// ══════════════════════════════════════════════════════════════════════════════
// Validation – derived
// ══════════════════════════════════════════════════════════════════════════════

final validationProvider = Provider<ProjectValidationState>((ref) {
  final project = ref.watch(projectProvider);
  return ValidationEngine.evaluate(project);
});
