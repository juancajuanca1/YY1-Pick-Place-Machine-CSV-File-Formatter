import 'package:flutter_test/flutter_test.dart';

import 'package:neoden_yy1_formatter/core/inference/field_inference_service.dart';
import 'package:neoden_yy1_formatter/core/ingest/file_ingestor.dart';
import 'package:neoden_yy1_formatter/core/models/board_side.dart';
import 'package:neoden_yy1_formatter/core/models/resolved_schema.dart';
import 'package:neoden_yy1_formatter/core/normalize/normalization_service.dart';

void main() {
  const fusionCsv = '''C1,81.25,68.99,0.00,0.1uF,CAPC3216X135
C10,48.59,26.99,90.00,47uF/16V,CAPM6032X280
FD1,48.39,36.45,0.00,FID_40MIL,FID_040
''';

  test(
    'imports headerless Fusion 360 placement rows without losing row one',
    () {
      final doc = FileIngestor.ingest(
        content: fusionCsv,
        fileName: 'PnP_Mixing Tank_front.csv',
      );

      expect(doc.hasSyntheticHeaders, isTrue);
      expect(doc.originalHeaders, [
        'Designator',
        'X',
        'Y',
        'Rotation',
        'Value',
        'Footprint',
      ]);
      expect(doc.rowCount, 3);
      expect(doc.rows.first[0], 'C1');
      expect(doc.inferredSide, BoardSide.top);

      final match = FieldInferenceService.inferSchema(doc);
      expect(match.isHighConfidence, isTrue);
      expect(match.columnFor(CanonicalField.value), 4);
      expect(match.columnFor(CanonicalField.footprint), 5);
      expect(match.columnFor(CanonicalField.side), -1);

      final records = NormalizationService.normalizeRows(
        doc,
        ResolvedSchema(columns: match.resolvedColumns, userConfirmed: false),
      );
      expect(records, hasLength(3));
      expect(records.first.value, '0.1uF');
      expect(records.first.footprint, 'CAPC3216X135');
      expect(records.first.side, BoardSide.top);
      expect(records.last.isFiducial, isTrue);
    },
  );

  test('infers bottom side from Fusion filename', () {
    final doc = FileIngestor.ingest(
      content: fusionCsv,
      fileName: 'controller_back.csv',
    );
    expect(doc.inferredSide, BoardSide.bottom);
  });
}
