import 'package:flutter_test/flutter_test.dart';

import 'package:neoden_yy1_formatter/core/inference/field_inference_service.dart';
import 'package:neoden_yy1_formatter/core/ingest/file_ingestor.dart';
import 'package:neoden_yy1_formatter/core/models/board_side.dart';
import 'package:neoden_yy1_formatter/core/models/resolved_schema.dart';
import 'package:neoden_yy1_formatter/core/normalize/normalization_service.dart';

void main() {
  const altiumCsv = '''Altium Designer Pick and Place Locations
C:\\Users\\Public\\Documents\\Altium\\Dynamic Survey Tool\\Project Outputs for Dynamic Survey Tool\\Pick Place for Board.csv

========================================================================================================================
File Design Information:

Date:       17/09/26
Time:       19:33
Revision:   9b9463d426e83dd75932ee24d8056f091d9c8543
Variant:    No variations
Units used: mm

"Designator","Comment","Layer","Footprint","Center-X(mm)","Center-Y(mm)","Rotation","Description"
"R34","MCT0603MD4700DP500","BottomLayer","ERA2AED122X","10.8966","98.3234","90","Res Thin Film 0402 4.7K Ohm 0.1% 0.063W Molded SMD"
"C152","CGA2B2NP01H220J050BA","TopLayer","CAPC1005X55N","25.6273","93.8053","90","25V 100nF X8L 10% 0402 Multilayer Ceramic Capacitors MLCC"
"J21","87898-0424","TopLayer","878980424","19.6850","53.3588","180","Conn Unshrouded Header HDR 4 POS 2.54mm Solder ST Top Entry SMD"
''';

  test('imports Altium pick-and-place CSV with preamble and layer names', () {
    final doc = FileIngestor.ingest(
      content: altiumCsv,
      fileName: 'Pick Place for Board.csv',
    );

    expect(doc.hasSyntheticHeaders, isFalse);
    expect(doc.rowCount, 3);
    expect(doc.originalHeaders, [
      'Designator',
      'Comment',
      'Layer',
      'Footprint',
      'Center-X(mm)',
      'Center-Y(mm)',
      'Rotation',
      'Description',
    ]);

    final match = FieldInferenceService.inferSchema(doc);
    expect(match.isHighConfidence, isTrue);
    expect(match.columnFor(CanonicalField.designator), 0);
    expect(match.columnFor(CanonicalField.value), 1);
    expect(match.columnFor(CanonicalField.side), 2);
    expect(match.columnFor(CanonicalField.footprint), 3);
    expect(match.columnFor(CanonicalField.x), 4);
    expect(match.columnFor(CanonicalField.y), 5);
    expect(match.columnFor(CanonicalField.rotation), 6);

    final records = NormalizationService.normalizeRows(
      doc,
      ResolvedSchema(columns: match.resolvedColumns, userConfirmed: false),
    );

    expect(records, hasLength(3));
    expect(records.first.designator, 'R34');
    expect(records.first.value, '4.7K');
    expect(records.first.footprint, '0402');
    expect(records.first.side, BoardSide.bottom);
    expect(records.first.xMm, 10.8966);
    expect(records.first.yMm, 98.3234);
    expect(records[1].designator, 'C152');
    expect(records[1].value, '100nF');
    expect(records[1].footprint, '0402');
    expect(records.last.designator, 'J21');
    expect(records.last.value, '87898-0424');
    expect(records.last.footprint, '878980424');
    expect(records.last.side, BoardSide.top);
    expect(records.last.rotationDeg, 180);
    expect(records.expand((record) => record.warnings), isEmpty);
  });
}